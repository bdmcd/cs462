ruleset wovyn_base {
    meta {
        use module twilio.sdk alias twilio with
            sid = meta:rulesetConfig{"sid"}
            token = meta:rulesetConfig{"token"}
    }

    global {
        temperature_threshold = 80
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
            tempF = tempData["temperatureF"]
        }
        always {
            raise wovyn event "threshold_violation" attributes {
                "temperature": tempF,
            } if (tempF > temperature_threshold);
        }
    }

    rule threshold_violation {
        select when wovyn threshold_violation
        pre {
            attributes = event:attributes.klog()
            temp = attributes["temperature"]
        }

        twilio:sendMessage("8017178175", "Temperature threshold violation, temperature: " + temp + " degrees farenheit") setting(response)
    }
}