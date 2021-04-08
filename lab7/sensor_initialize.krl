ruleset sensor_initialize {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares subscriptionTx, sensorId
    }

    global {
        subscriptionTx = function() {
            return ent:subscriptionTx
        }

        sensorId = function() {
            ent:sensor_id
        }
    }

    rule save_sensor_info {
        select when sensor init
        always {
            ent:sensor_id := event:attrs{"name"}
        }
    }

    rule capture_initial_state {
        select when wrangler ruleset_installed
            where event:attrs{"rids"} >< meta:rid
        pre {
            sensor_id = event:attrs{"name"}
        }
        if ent:subscriptionTx.isnull() then
            event:send({
                "eci": wrangler:parent_eci(),
                "domain":"sensor", 
                "type":"init_subscription",
                "attrs":{
                    "sensor_id": ent:sensor_id,
                    "wellKnown_Tx": subs:wellKnown_Rx(){"id"}
                }
            })
        fired {
            ent:sensor_id := sensor_id
        }
    }

    rule auto_accept_subscription {
        select when wrangler new_subscription_request
        if event:attrs{"Rx_role"}=="sensor" && event:attrs{"Tx_role"}=="collection" 
            then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
                attributes event:attrs
            ent:subscribed := true
        } else {
            raise wrangler event "inbound_rejection"
                attributes event:attrs
        }
    }

    rule save_tx_info {
        select when wrangler subscription_added
        event:send({
            "eci": wrangler:parent_eci(),
            "domain": "sensor", 
            "type": "subscription_accepted",
            "attrs":{
                "sensor_id": ent:sensor_id, //TODO: change this
                "tx": event:attrs{"Rx"}
            }
        })
    }
}