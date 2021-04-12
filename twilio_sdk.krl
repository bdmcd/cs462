ruleset twilio.sdk {
    meta {
        configure using
            sid = meta:rulesetConfig{"sid"}
            token = meta:rulesetConfig{"token"}
        provide
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

    rule sendMessage {
        select when twilio sendMessage
        pre {
            data = {
                "Body": event:attrs{"message"},
                "From": "(231) 241-6658",
                "To": event:attrs{"to"}
            };

            auth = {
                "username": sid,
                "password": token
            }
        }
        http:post(<<#{base_url}/#{sid}/Messages>>, form=data, auth=auth) setting(response)
    }
}