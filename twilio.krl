ruleset twilio {
    meta {
        use module twilio.sdk alias twilio with
            sid = meta:rulesetConfig{"sid"}
            token = meta:rulesetConfig{"token"}

        shares
            getMessages
    }

    global {
        getMessages = function(pageSize, page, pageToken, toFilter, fromFilter) {
            twilio:messages(pageSize, page, pageToken, toFilter, fromFilter)
        }
    }
    
    rule send_message {
        select when send sms
        pre {
            to = event:attr("to").klog("our passed in number: ")
            message = event:attr("message").klog("our passed in message: ")
        }
        twilio:sendMessage(to, message) setting(response)
        fired {
            ent:lastResponse := response
            ent:lastTimestamp := time:now()
        }
    }
}