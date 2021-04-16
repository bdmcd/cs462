ruleset gossip {
    meta {
        use module io.picolabs.subscription alias subscriptions
        shares originId, sequenceId, selfState, state, temperatureLogs, subscriptionInfo, processing
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

        processing = function() {
            ent:processing
        }

        getPeersNeededInfo = function() {
            peers = subscriptions:established().map(function(sub) {
                tx = sub{"Tx"}
                peer = ent:subscriberMap{tx}
                data = {}.put(peer, ent:state{peer})
                data
            }).reduce(function(a, b) {
                a.put(b)
            })

            neededInfo = peers.map(function(peerState, peerId) {
                selfState().defaultsTo({}).map(function(whatIThink, sensorId) {
                    whatTheyThink = peerState{sensorId} == null => -1 | peerState{sensorId}
                    whatTheyNeed = whatIThink > whatTheyThink => whatTheyThink + 1 | null
                    whatTheyNeed
                }).filter(function(whatTheyNeed, sensorId) {
                    whatTheyNeed != null && sensorId != peerId
                })
            }).filter(function(everythingTheyNeed, sensorId) {
                everythingTheyNeed.length() > 0
            })
            neededInfo
        }

        getMyNeededInfo = function() {
            peers = subscriptions:established().map(function(sub) {
                tx = sub{"Tx"}
                peer = ent:subscriberMap{tx}
                peer
            })

            peers
        }

        getRumorMessage = function() {
            peersNeededInfo = getPeersNeededInfo()
            random = random:integer(peersNeededInfo.length()-1)
            chosenPeer = peersNeededInfo.keys()[random]
            whatTheyNeed = peersNeededInfo{chosenPeer}
            random2 = random:integer(whatTheyNeed.length()-1)
            selectedSensorIdToSend = whatTheyNeed.keys()[random2]
            selectedSequenceIdToSend = whatTheyNeed{selectedSensorIdToSend}
            
            messageId = selectedSensorIdToSend + ":" + selectedSequenceIdToSend
            temperatureLog = temperatureLogs(){[selectedSensorIdToSend, messageId]}
            
            message = peersNeededInfo.length() > 0 => {
                "senderId": originId(),
                "chosenPeer": chosenPeer,
                "messageId": messageId,
                "temperature": temperatureLog{"temperature"},
                "timestamp": temperatureLog{"timestamp"}
            } | null
            message
        }

        getSeenMessage = function() {
            peers = getMyNeededInfo()
            random = random:integer(peers.length()-1)
            chosenPeer = peers[random]
            
            message = peers.length() > 0 => {
                "senderId": originId(),
                "chosenPeer": chosenPeer,
                "state": selfState().defaultsTo({})
            } | null
            message
        }
    }

    rule reset {
        select when gossip reset
        always {
            ent:originId := random:uuid()
            ent:sequenceId := 0
            ent:state := {}
            ent:temperatureLogs := {}
            ent:subscriberMap := {}
            ent:processing := 1
        }
    }

    rule init {
        select when gossip init
        fired {
            ent:state := {}
            ent:temperatureLogs := {}
            ent:sequenceId := 0
        }
    }

    rule set_processing {
        select when gossip process
        fired {
            ent:processing := event:attrs{"proccess"}.as("Number")
        }
    }

    rule init_subscription_exchange {
        select when gossip init_subscription_exchange
        foreach subscriptions:established() setting(sub)
        pre {
            rx = sub{"Rx"}
            tx = sub{"Tx"}
        }
        if sub{"Rx_role"} == "node" && sub{"Rx_role"} == "node" then
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

    rule start_heartbeat {
        select when gossip start_heartbeat
        if ent:heartbeat_id then schedule:remove(ent:heartbeat_id)
        always {
            schedule gossip event "heartbeat" repeat "*/" + event:attrs{"seconds"} + "  *  * * * *" setting(heartbeat_id)
            ent:heartbeat_id := heartbeat_id
        }
    }

    rule stop_heartbeat {
        select when gossip stop_heartbeat
        schedule:remove(ent:heartbeat_id)
    }

    rule heartbeat {
        select when gossip heartbeat
            where ent:processing
        pre {
            random = random:integer(1)
            messageType = random == 0 => "rumor" | "seen"
        }
        fired {
            raise gossip event "send_" + messageType
        }
    }

    rule new_temperature {
        select when gossip new_temperature
        always {
            ent:temperatureLogs{[originId(), messageId(), "messageId"]} := messageId()
            ent:temperatureLogs{[originId(), messageId(), "temperature"]} := event:attrs{"temperature"}
            ent:temperatureLogs{[originId(), messageId(), "timestamp"]} := event:attrs{"timestamp"}

            ent:state{[originId(), originId()]} := ent:sequenceId
            ent:sequenceId := ent:sequenceId + 1
        }
    }

    rule send_rumor {
        select when gossip send_rumor
            where ent:processing
        pre {
            message = getRumorMessage()
            chosenPeer = message{"chosenPeer"}
        }
        if message != null then
        event:send({
            "eci": ent:subscriberMap{chosenPeer},
            "domain": "gossip",
            "type": "rumor",
            "attrs": message
        })
        fired {
            messageData = message{"messageId"}.split(":")
            ent:state{[chosenPeer, messageData[0]]} := messageData[1].as("Number")
        }
    }

    rule send_seen {
        select when gossip send_seen
            where ent:processing
        pre {
            message = getSeenMessage()
            chosenPeer = message{"chosenPeer"}
        }
        if message != null then
        event:send({
            "eci": ent:subscriberMap{chosenPeer},
            "domain": "gossip",
            "type": "seen",
            "attrs": message
        })
    }

    rule recieve_rumor {
        select when gossip rumor
            where ent:processing
        pre {
            messageId = event:attrs{"messageId"}
            messageData = messageId.split(":")
            subjectSensorId = messageData[0]
            subjectSequenceIdStr = messageData[1]
            subjectSequenceId = messageData[1].as("Number")
            myCurrentSequenceId = selfState(){subjectSensorId} == null => -1 | selfState(){subjectSensorId}

            senderId = event:attrs{"senderId"}
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        if subjectSequenceId == (myCurrentSequenceId + 1) then noop()
        fired {
            ent:temperatureLogs{[subjectSensorId, messageId, "messageId"]} := messageId
            ent:temperatureLogs{[subjectSensorId, messageId, "temperature"]} := temperature
            ent:temperatureLogs{[subjectSensorId, messageId, "timestamp"]} := timestamp

            ent:state{[senderId, subjectSensorId]} := subjectSequenceId
            ent:state{[originId(), subjectSensorId]} := subjectSequenceId
        } else {
            ent:temperatureLogs{[subjectSensorId, messageId, "messageId"]} := messageId
            ent:temperatureLogs{[subjectSensorId, messageId, "temperature"]} := temperature
            ent:temperatureLogs{[subjectSensorId, messageId, "timestamp"]} := timestamp

            ent:state{[senderId, subjectSensorId]} := subjectSequenceId
        }
    }

    rule recieve_seen {
        select when gossip seen
            where ent:processing
        foreach ent:state{originId()} setting(mySubjectSequenceId, subjectSensorId)
        pre {
            senderId = event:attrs{"senderId"}
            senderState = event:attrs{"state"}
            senderCurrentSequenceId = senderState{subjectSensorId} == null => -1 | senderState{subjectSensorId}
            nextNeededSequenceId = senderCurrentSequenceId + 1
            messageIdToSend = subjectSensorId + ":" + nextNeededSequenceId
            temperatureLog = temperatureLogs(){[subjectSensorId, messageIdToSend]}
        }
        if mySubjectSequenceId >= nextNeededSequenceId then 
            event:send({
                "eci": ent:subscriberMap{senderId},
                "domain": "gossip",
                "type": "rumor",
                "attrs": {
                    "senderId": originId(),
                    "messageId": messageIdToSend,
                    "temperature": temperatureLog{"temperature"},
                    "timestamp": temperatureLog{"timestamp"},
                }
            })
        fired {
            //update state at senderid to the information sent
            ent:state{[senderId, subjectSensorId]} := nextNeededSequenceId
        } else {
            //update state at senderid to the information recieved
            ent:state{[senderId, subjectSensorId]} := senderCurrentSequenceId
        }
    }

    rule subscription_exchange {
        select when gossip subscription_exchange
        pre {
            sensorEci = event:attrs{"sensorEci"}
            sensorId = event:attrs{"sensorId"}
        }
        always {
            ent:subscriberMap{sensorEci} := sensorId
            ent:subscriberMap{sensorId} := sensorEci
        }
    }
}