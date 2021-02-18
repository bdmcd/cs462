ruleset twilio.sdk {
    meta {
        configure using
            sid = "ACa89e9e019a4e1b6fead6cebf69554ac4"
            token = "819241029b4de645b093ca825fc1bf6d"

        provides 
            sendMessage
        shares
            messages
    }

    global {
        base_url = "https://api.twilio.com/2010-04-01/Accounts"
        sendMessage = defaction(to, message) {
            data = {
                "Body": message,
                "From": "(231) 241-6658",
                "To": to
            };

            auth = {
                "username": sid,
                "password": token
            }

            http:post(<<#{base_url}/#{sid}/Messages>>, form=data, auth=auth) setting(response)
            return response
        }

        messages = function(pageSize, page, pageToken, toFilter, fromFilter) {
            queryString = pageSize => {"PageSize" : pageSize} | {} 
            queryString1 = page => queryString.put({"Page" : page}) | queryString
            queryString2 = pageToken => queryString1.put({"PageToken" : pageToken}) | queryString1
            queryString3 = toFilter => queryString2.put({"To" : toFilter}) | queryString2
            queryString4 = fromFilter => queryString3.put({"From" : fromFilter}) | queryString3

            auth = {
                "username": sid,
                "password": token
            }
            response = http:get(<<#{base_url}/#{sid}/Messages.json>>, qs=queryString4, auth=auth);
            return response{"content"}.decode();
        }

        lastResponse = function() {
            {}.put(ent:lastTimestamp,ent:lastResponse)
        }
    }

    rule send_message {
        select when send sms
        pre {
            to = event:attr("to").klog("our passed in number: ")
            message = event:attr("message").klog("our passed in message: ")
        }
        sendMessage(to, message) setting(response)
        fired {
            ent:lastResponse := response
            ent:lastTimestamp := time:now()
        }
    }
}