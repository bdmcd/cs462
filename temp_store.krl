ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        temperatures = function() {
            ent:readings
        }

        threshold_violations = function() {
            ent:violations
        }

        inrange_temperatures = function() {
            ent:readings.filter(function(x) {
                ent:violations.any(function(y){ 
                    y{"timestamp"} == x{"timestamp"}
                }) => false | true
            })
        }
    }

    rule collect_temperature {
        select when wovyn new_temperature_reading
        pre {
            temp = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
        }
        always {
            ent:readings := ent:readings.defaultsTo([]).append({"temperature": temp, "timestamp": time})
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            temp = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
        }
        always {
            ent:violations := ent:violations.defaultsTo([]).append({"temperature": temp, "timestamp": time})
        }
    }

    rule clear_temeratures
    {
        select when sensor reading_reset
        always {
            ent:readings := []
            ent:violations := []
        }
    }

    rule send_temperature_to_collection {
        select when sensor collect_sensor_temperature
        pre {
            readings = ent:readings.defaultsTo([])
            correlation_id = event:attrs{"correlation_id"}
            collection_eci = event:attrs{"tx"}
            sensor_eci = event:attrs{"rx"}
            sensor_id = event:attrs{"sensor_id"}
            temperature = readings[readings.length() - 1]{"temperature"}[0]
        }
        event:send({ 
            "eci": collection_eci, 
            "domain": "sensor", 
            "type": "send_temperature",
            "attrs": {
                "sensor_id": sensor_id,
                "sensor_rx": sensor_eci,
                "temperature": temperature,
                "correlation_id": correlation_id
            }
        })
    }
}