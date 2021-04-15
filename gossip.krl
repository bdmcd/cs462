ruleset gossip {
    meta {
        use module io.picolabs.subscription alias subscriptions
        shares originId, sequenceId, messageId, selfState, state, temperatureLogs, subscriptionInfo, getRumorMessage, getSeenMessage
    }

    global {
        originId = function() {
            ent:originId
        }

        sequenceId = function() {
            ent:sequenceId
        }

        messageId = function() {
            originId() + ":" + sequenceId()
        }
        
        selfState = function() {
            ent:state{originId()}
        }

        state = function() {
            ent:state
        }

        temperatureLogs = function() {
            ent:temperatureLogs
        }

        subscriptionInfo = function() {
            ent:subscriberMap
        }

        getPeer = function() {
            subs = subscriptions:established().map(function(sub) {
                sub{"Tx"}
            })
            peers = subs.map(function(tx) {
                peerId = ent:subscriberMap{tx}
                result = {}.put(peerId, ent:state{peerId})
                result
            })
            peersWithNeededInfo = peers.filter(function(peer) {
                peerState = peer.values()[0]
                neededStates = peerState.filter(function(sequence, sensor) {
                    selfState()[sensor] > sequence
                })
                neededStates.length() > 0
            })
            
            random = random:integer(peersWithNeededInfo.length() - 1)
            peersWithNeededInfo[random].keys()[0]
        }

        getRumorMessage = function(peer) {
            peerState = ent:state{peer}
            needed = selfState().filter(function(sequence, sensor) {
                peerState[sensor] < sequence
            })
            random = random:integer(needed.length() - 1)
            choice = needed.keys()[random]
            messageId = choice + ":" + selfState()[choice]
            message = {
                "messageId": messageId,
                "senderId": originId(),
                "temperature": temperatureLogs(){[choice, messageId, "temperature"]},
                "timestamp": temperatureLogs(){[choice, messageId, "timestamp"]}
            }
            message
        }

        getSeenMessage = function(peer) {
            sensors = subscriptions:established().map(function(sub) {
                ent:subscriberMap{sub{"Tx"}}
            }).append(originId())
            random = random:integer(sensors.length() - 1)
            sensor = sensors[random]

            message = {
                "senderId": originId(),
                "sensorId": sensor,
                "state": ent:state{sensor}
            }
            message
        }
    }

    rule init {
        select when gossip init
        always {
            ent:originId := random:uuid()
            ent:sequenceId := 0
            ent:state := {}
            ent:temperatureLogs := {}
            ent:subscriberMap := {}
        }
    }

    rule init_subscription_exchange {
        select when gossip init_subscription_exchange
        foreach subscriptions:established() setting(sub)
        pre {
            rx = sub{"Rx"}
            tx = sub{"Tx"}
        }
        event:send({
            "eci": tx, 
            "domain": "gossip", 
            "type": "subscription_exchange",
            "attrs": {
                "sensorEci": rx,
                "sensorId": ent:originId,
            }
        })
    }

    rule init_state {
        select when gossip init_state
        pre {
            subs = subscriptions:established()
        }
        fired {
            ent:state := subs.map(function(sub) {
                {}.put(ent:subscriberMap{sub{"Tx"}}, subs.map(function(s) {
                    {}.put(ent:subscriberMap{s{"Tx"}}, -1)
                }).reduce(function(a, b) {
                    a.put(b)
                }).put(originId(), -1))
            }).reduce(function(a, b) {
                a.put(b)
            }).put(originId(), subs.map(function(s) {
                {}.put(ent:subscriberMap{s{"Tx"}}, -1)
            }).reduce(function(a, b) {
                a.put(b)
            }).put(originId(), -1))
        }
    }

    rule start_heartbeat {
        select when gossip start_heartbeat
        fired {
            schedule gossip event "heartbeat" repeat "*/5  *  * * * *" setting(heartbeat_id)
            ent:heartbeat_id := heartbeat_id
        }
    }

    rule stop_heartbeat {
        select when gossip stop_heartbeat
        schedule:remove(ent:heartbeat_id)
    }

    rule stop_all_heartbeats {
        select when gossip stop_all_heartbeats
        foreach schedule:list() setting(heartbeat)
        schedule:remove(heartbeat{"id"})
    }

    rule heartbeat {
        select when gossip heartbeat
        pre {
            random = random:integer(1)
            messageType = random == 0 => "rumor" | "seen"
        }
        fired {
            raise gossip event "send_" + messageType
        }
    }

    rule send_rumor {
        select when gossip send_rumor
        pre {
            peer = getPeer()
            message = getRumorMessage(peer)
            messageInfo = message{"messageId"}.split(":")
            tx = ent:subscriberMap{peer}
        }
        if peer != null then event:send({
            "eci": tx, 
            "domain": "gossip", 
            "type": "rumor",
            "attrs": message
        })

        fired {
            ent:state{[peer, messageInfo[0]]} := messageInfo[1].as("Number")
        }
    }

    rule send_seen {
        select when gossip send_seen
        pre {
            peer = getPeer()
            message = getSeenMessage(peer)
            messageInfo = message{"messageId"}.split(":")
            tx = ent:subscriberMap{peer}
        }
        if peer != null then event:send({
            "eci": tx, 
            "domain": "gossip", 
            "type": "seen",
            "attrs": message
        })
    }

    rule recieve_rumor {
        select when gossip rumor
        pre {
            messageId = event:attrs{"messageId"}
            messageData = messageId.split(":")
            originId = messageData[0]
            originSequenceId = messageData[1].as("Number")
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}

            senderId = event:attrs{"senderId"}
            mySequenceId = ent:state{[ent:originId, originId]}
        }
        if originSequenceId == mySequenceId + 1 then noop()
        fired {
            ent:state{[ent:originId, originId]} := originSequenceId
        }
        finally {
            ent:state{[senderId, originId]} := originSequenceId
            ent:temperatureLogs{[originId, messageId]} := {
                "messageId": messageId,
                "sensorId": originId,
                "temperature": temperature,
                "timestamp": timestamp
            }
        }
    }

    rule recieve_seen {
        select when gossip seen
        foreach event:attrs{"state"} setting(sequenceId, stateSensorId)
        pre {
            senderId = event:attrs{"senderId"}
            sensorId = event:attrs{"sensorId"}
            mySequenceId = ent:state{[sensorId, stateSensorId]}
            messageId = stateSensorId + ":" + mySequenceId
        }
        if mySequenceId == sequenceId + 1 then
            event:send({
                "eci": ent:subscriberMap{senderId}, 
                "domain": "gossip", 
                "type": "rumor",
                "attrs": {
                    "messageId": messageId,
                    "senderId": originId(),
                    "temperature": temperatureLogs(){[stateSensorId, messageId, "temperature"]},
                    "timestamp": temperatureLogs(){[stateSensorId, messageId, "timestamp"]}
                }
            })
        fired {
        } else {
            ent:state{[sensorId, stateSensorId]} := sequenceId
        }
    }

    rule subscription_exchange {
        select when gossip subscription_exchange
        pre {
            sensorEci = event:attrs{"sensorEci"}
            sensorId = event:attrs{"sensorId"}
        }
        if not ent:subscriberMap{sensorEci} then noop()
        fired {
            ent:subscriberMap{sensorEci} := sensorId
            ent:subscriberMap{sensorId} := sensorEci
            raise gossip event "init_subscription_exchange"
        }
    }
}