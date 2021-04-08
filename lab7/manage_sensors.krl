ruleset manage_sensors {
    meta {
        use module twilio.sdk alias twilio with
            sid = meta:rulesetConfig{"sid"}
            token = meta:rulesetConfig{"token"}

        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs

        shares showSubs, sensors, temperatures
    }

    global {
        nameFromID = function(sensor_id) {
            sensor_id + " Pico"
        }

        showSubs = function() {
            subs:established().filter(function(sub) {
                sub["Rx_role"] == "collection" && sub["Tx_role"] == "sensor"
            })
        }
        sensors = function() {
            ent:sensors
        }

        temperatures = function() {
            ent:sensors.map(function(value, key) {
                wrangler:picoQuery(value{"tx"}, "temperature_store", "temperatures", {});
                // value
            })
            // ent:sensors.keys().map(function(sensor_id) {
            //     tx = ent:sensors{sensor_id}{"tx"}
            //     response = wrangler:picoQuery(tx, "temperature_store", "temperatures", {});
            //     {}.put(sensor_id, response)
            // })
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
        foreach ["sensor_initialize", "twilio_sdk", "sensor_profile", "wovyn", "temp_store"] setting(rid, i)
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
                        "confi": {},
                        "sensor_id": sensor_id
                    }
                }
            )
    }

    rule add_external_sensor {
        select when sensor add_external
        foreach ["sensor_initialize", "twilio_sdk", "sensor_profile", "wovyn", "temp_store"] setting(rid, i)
        pre {
            sensor_eci = event:attrs{"eci"}
            sensor_id = event:attrs{"sensor_id"}
        }
        event:send(
            { 
                "eci": sensor_eci,
                "eid": "install-ruleset",
                "domain": "wrangler", 
                "type": "install_ruleset_request",
                "attrs": {
                    "absoluteURL": meta:rulesetURI,
                    "rid": rid,
                    "sender_tx": wrangler:myself(){"eci"},
                    "sensor_id": sensor_id
                }
            }
        )
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
                    "domain": "sensor", 
                    "type": "init",
                    "attrs": {
                        "name": sensor_id,
                        "threshold": 80,
                        "number": "",
                        "location": ""
                    }
                }
            )
        fired {
            ent:sensors{sensor_id} := the_sensor
        }
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

    rule make_subscription_to_sensor {
        select when sensor init_subscription
        pre {
            tx = event:attrs{"wellKnown_Tx"}
            sensor_id = event:attrs{"sensor_id"}
        }
        always {
            raise wrangler event "subscription"
                attributes {
                    "wellKnown_Tx": tx,
                    "Tx_role": "sensor",
                    "Rx_role": "collection",
                    "Name": sensor_id,
                    "channel_type": "sensor_subscription"
                }
        }
    }

    rule save_sensor_subscription_info {
        select when sensor subscription_accepted
        always {
            ent:sensors{[event:attrs{"sensor_id"}, "rx"]} := event:attrs{"rx"}
        }
    }

    rule send_added_status {
        select when wrangler subscription_added
        event:send({
            "eci": event:attrs{"Tx"},
            "domain": "sensor", 
            "type": "subscription_added",
            "attrs":{
                "Rx": event:attrs{"Tx"},
                "Tx": event:attrs{"Rx"},
            }
        })
    }

    rule save_subscription_info {
        select when sensor subscription_accepted
        always {
            ent:sensors{[event:attrs{"sensor_id"}, "rx"]} := event:attrs{"Rx"}
            ent:sensors{[event:attrs{"sensor_id"}, "tx"]} := event:attrs{"Tx"}
        }
    }

    rule send_sensor_violations {
        select when sensor child_threshold_violation
        always {
            raise twilio event "sendMessage"
                attributes {
                    "to": "8017178175",
                    "message": event:attrs{"sensor_id"} + ": temperature threshold violation, (" + event:attrs{"temp"} + " degrees farenheit)"
                }   
        }
    }
}