ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        shares showChildren, sensors, temperatures
    }

    global {
        nameFromID = function(sensor_id) {
            sensor_id + " Pico"
        }

        showChildren = function() {
            wrangler:children()
        }

        sensors = function() {
            ent:sensors
        }

        temperatures = function() {
            ent:sensors.keys().map(function(sensor_id) {
                eci = ent:sensors{sensor_id}{"eci"}
                response = wrangler:picoQuery(eci, "temperature_store", "temperatures", {});
                {}.put(sensor_id, response)
            })
        }
    }

    rule sensor_already_exists {
        select when sensor needed
        pre {
            sensor_id = event:attr("sensor_id")
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if exists then
            send_directive("sensor_ready", {"sensor_id":sensor_id})
    }

    rule sensor_does_not_exist {
        select when sensor needed
        pre {
            sensor_id = event:attr("sensor_id")
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if not exists then noop()
        fired {
            raise wrangler event "new_child_request"
                attributes { "name": nameFromID(sensor_id), "backgroundColor": "#ff69b4", "sensor_id": sensor_id }
        }
    }

    rule store_new_sensor {
        select when wrangler new_child_created
        foreach ["twilio_sdk", "sensor_profile", "wovyn", "temp_store"] setting(rid, i)
        pre {
            the_sensor = {"eci": event:attr("eci")}
            sensor_id = event:attr("sensor_id")
        }
        if sensor_id.klog("found sensor_id")
            then event:send(
                { 
                    "eci": the_sensor.get("eci"), 
                    "eid": "install-ruleset",
                    "domain": "wrangler", "type": "install_ruleset_request",
                    "attrs": {
                        "absoluteURL": meta:rulesetURI,
                        "rid": rid,
                        "config": {"sid":"ACa89e9e019a4e1b6fead6cebf69554ac4","token":"819241029b4de645b093ca825fc1bf6d"},
                        "sensor_id": sensor_id
                    }
                }
            )
        fired {
            ent:sensors{sensor_id} := the_sensor
        }
    }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attr("sensor_id")
            exists = ent:sensors >< sensor_id
            eci_to_delete = ent:sensors{[sensor_id,"eci"]}
        }
            if exists && eci_to_delete then
            send_directive("deleting_sensor", {"sensor_id":sensor_id})
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": eci_to_delete};
            clear ent:sensors{sensor_id}
        }
    }

    rule init_child_profile {
        select when wrangler new_child_created
        pre {
            the_sensor = {"eci": event:attr("eci")}
            sensor_id = event:attr("sensor_id")
        }
        if sensor_id.klog("found sensor_id")
            then event:send(
                { 
                    "eci": the_sensor.get("eci"), 
                    "eid": "init_profile",
                    "domain": "sensor", "type": "profile_updated",
                    "attrs": {
                        "name": sensor_id,
                        "threshold": 80,
                        "number": "",
                        "location": ""
                    }
                }
            )
    }

    rule initialize_sensors {
        select when sensor needs_initialization
        foreach ent:sensors setting(value, name)
        always {
            raise sensor event "unneeded_sensor"
                attributes {
                    "sensor_id": name
                }
        }
    }
}