ruleset wovyn_base {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        use module sensor_profile alias profile
        use module sensor_initialize alias sensor
    }

    global {

    }

    rule process_heartbeat {
        select when wovyn heartbeat
        pre {
            attributes = event:attrs.klog("")
            generic_thing = attributes["genericThing"]
            profileData = profile:getProfile()
        }
        always {
            ent:profile_threshold := profileData{"threshold"}.defaultsTo("")
            ent:profile_number := profileData{"number"}.defaultsTo(80)

            raise wovyn event "new_temperature_reading" attributes {
                "temperature": generic_thing["data"]["temperature"],
                "timestamp": time:now()
            } if (generic_thing);
        }
    }

    rule temperature {
        select when wovyn new_temperature_reading
        pre {
            attributes = event:attrs
        }

        send_directive("attrs", attributes)
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            tempData = event:attrs["temperature"][0]
            timestamp = event:attrs{"timestamp"}
        }
        always {
            raise wovyn event "threshold_violation" attributes {
                "temperature": tempData,
                "timestamp": timestamp
            } if (tempData["temperatureF"] > ent:profile_threshold);
        }
    }

    rule threshold_violation {
        select when wovyn threshold_violation
        pre {
            tempData = event:attrs{"temperature"}
            temp = tempData["temperatureF"]
        }

        send_directive({
            "eci": sensor:subscriptionTx(),
            "domain":"sensor", 
            "type":"child_threshold_violation",
            "attrs":{
                "temp": temp,
                "sensor_id": sensor:sensorId()
            }
        })
    }
}