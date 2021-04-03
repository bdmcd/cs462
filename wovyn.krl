ruleset wovyn_base {
    meta {
        use module twilio.sdk alias twilio with
            sid = meta:rulesetConfig{"sid"}
            token = meta:rulesetConfig{"token"}

        shares getProfile
    }

    global {
        temperature_threshold = ent:threshold.defaultsTo(80)

        getProfile = function() {
            return {
                "threshold": ent:threshold,
                "number": ent:number
            }
        }
    }

    rule process_heartbeat {
        select when wovyn heartbeat
        pre {
            attributes = event:attrs.klog("")
            generic_thing = attributes["genericThing"]
        }
        always {
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
        send_directive("number", { "number": ent:threshold.defaultsTo(80) })
        always {
            raise wovyn event "threshold_violation" attributes {
                "temperature": tempData,
                "timestamp": timestamp
            } if (tempData["temperatureF"] > temperature_threshold);
        }
    }

    rule threshold_violation {
        select when wovyn threshold_violation
        pre {
            attributes = event:attrs.klog()
            tempData = attributes["temperature"]
            temp = tempData["temperatureF"]
        }

        send_directive("test", { "number": ent:number.defaultsTo("") })
        // twilio:sendMessage(number, "Temperature threshold violation, temperature: " + temp + " degrees farenheit") setting(response)
    }
}