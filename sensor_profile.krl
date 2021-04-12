ruleset sensor_profile {
    meta {
        shares getProfile
        provide getProfile
    }
    global {
        getProfile = function() {
            return {
                "name": ent:name,
                "threshold": ent:threshold,
                "location": ent:location,
                "number": ent:number
            }
        }
    }
    
    rule profile_init {
        select when sensor init
        pre {
            name = event:attr("name")
            threshold = event:attr("threshold")
            location = event:attr("location")
            number = event:attr("number")
        }
        always {
            ent:name := name
            ent:threshold := threshold
            ent:location := location
            ent:number := number
        }
    }

    rule profile_updated {
        select when sensor profile_updated
        pre {
            name = event:attr("name")
            threshold = event:attr("threshold")
            location = event:attr("location")
            number = event:attr("number")
        }
        always {
            ent:name := name
            ent:threshold := threshold
            ent:location := location
            ent:number := number
        }
    }
}