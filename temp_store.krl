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
}