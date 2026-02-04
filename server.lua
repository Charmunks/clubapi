local server = require("http").server.new()
local airtable = require("utils/airtable")
local url = require("utils/urlparams")
local auth = require("utils/auth")
local log = require("utils/logging")


-----------------
-- GET RECORDS --
-----------------


server:static_file("/", "docs.html")
server:static_file("/openapi.yaml", "openapi.yaml")


-- CLUB MANAGEMENT

server:get("/clubs", function(req)
    return {totalClubs  = airtable.list_records("Clubs", "Ivie ByID").records[1].fields.id}
end)

server:get("/clubs/map", function(req, res)
    log.request(req:uri(), req:headers())
    res:set_header("Access-Control-Allow-Origin", "*")
    local fields = {"club_name", "venue_lat_fuzz", "venue_lng_fuzz", "club_status"}
    local result = {}
    local offset = nil
    repeat
        local data = airtable.list_records("Clubs", "Map", {fields = fields, offset = offset})
        if data and data.records then
            for _, club in ipairs(data.records) do
                table.insert(result, {
                    id = club.id,
                    fields = {
                        club_name = club.fields.club_name,
                        venue_lat_fuzz = club.fields.venue_lat_fuzz,
                        venue_lng_fuzz = club.fields.venue_lng_fuzz,
                        club_status = club.fields.club_status
                    }
                })
            end
            offset = data.offset
        else
            offset = nil
        end
    until not offset
    return result
end)

server:get("/clubs/country", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.country == nil then
        return {error = "Missing country parameter"}
    end
    local formula = airtable.safeFormula("venue_address_country", params.country)
    return {clubs  = airtable.count_records("Clubs", formula)}
end)

server:get("/clubs/level", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.level == nil then
        return {error = "Missing level parameter"}
    end
    local stripped = url.strip_quotes(params.level)
    local levelValue = "level " .. airtable.sanitizeFormulaValue(stripped)
    local formula = airtable.safeFormula("level", levelValue)
    return {clubs  = airtable.count_records("Clubs", formula)}
end)

server:get("/club/code", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.code == nil then
            return {error = "Missing code parameter"}
        end
        local formula = airtable.safeFormula("Join Code", params.code)
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York"}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        return club
    else
        return {error = "Unauthorized"}
    end
end)

server:get("/club", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.name == nil then
        return {error = "Missing name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.name)
    if auth.checkRead(req:headers().authorization) == false then
        local fields = {"Est. # of Attendees", "call_meeting_days", "call_meeting_length", "club_name", "club_status", "id", "leader_slack_id", "level", "venue_address_country"}
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {club_name = nil}
        end
        return club
    else 
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York"}).records[1]
        if club == nil then
            return {club_name = nil}
        end
        return club
    end
end)

server:get("/club/ambassador", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.name == nil then
        return {error = "Missing name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.name)
    local fields = {"rel_ambassador"}
    local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
    if club == nil then
        return {error = "Club not found"}
    end
    local ambassadorId = club.fields.rel_ambassador
    if ambassadorId == nil then
        return {error = "No ambassador assigned"}
    end
    local ambassador = airtable.get_record("Ambassadors", ambassadorId[1])
    if ambassador == nil then
        return {error = "Ambassador not found"}
    end
    return {email = ambassador.fields.email, slackId = ambassador.fields["Slack ID"], desc = ambassador.fields.desc, pfp = ambassador.fields.pfp[1].thumbnails.full.url}
end)

-- LEADER MANAGEMENT 

server:get("/leader", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.email == nil then
        return {error = "Missing email parameter"}
    end
    local formula = airtable.safeFormula("email", params.email)
    local fields = {"rel_leader_to_clubs", "rel_co_leader_to_clubs"}
    if auth.checkRead(req:headers().authorization) then
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        local club = nil
        if leader == nil then
            return {club_name = nil}
        end
        if leader.fields.rel_leader_to_clubs then
            club = leader.fields.rel_leader_to_clubs[1]
        elseif leader.fields.rel_co_leader_to_clubs then
            club = leader.fields.rel_co_leader_to_clubs[1]
        end
        local clubfields = airtable.get_record("Clubs", club).fields
        local club_name = clubfields.club_name
        local club_status = clubfields.club_status
        return {club_name = club_name, club_status = club_status}
    else 
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields})
        if leader.records[1] == nil then
            return {leader = false}
        else 
            return {leader = true}
        end
    end
end)

server:get("/leader/slack", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.slackid == nil then
        return {error = "Missing slackid parameter"}
    end
    local formula = airtable.safeFormula("slack_id", params.slackid)
    local fields = {"rel_leader_to_clubs", "rel_co_leader_to_clubs"}
    if auth.checkRead(req:headers().authorization) then
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        local club = nil
        if leader == nil then
            return {club_name = nil}
        end
        if leader.fields.rel_leader_to_clubs then
            club = leader.fields.rel_leader_to_clubs[1]
        elseif leader.fields.rel_co_leader_to_clubs then
            club = leader.fields.rel_co_leader_to_clubs[1]
        end
        local clubfields = airtable.get_record("Clubs", club).fields
        local club_name = clubfields.club_name
        local club_status = clubfields.club_status
        return {club_name = club_name, club_status = club_status}
    else 
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields})
        if leader.records[1] == nil then
            return {leader = false}
        else 
            return {leader = true}
        end
    end
end)

-- SHIP MANAGEMENT

server:get("/ships", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.club_name == nil then
        return {error = "Missing club_name parameter"}
    end
    local formula = airtable.safeFormula("club_name (from Clubs)", params.club_name)
    if auth.checkRead(req:headers().authorization) == false then
        local fields = {"workshop", "Rating", "code_url", "club_name (from Clubs)", "YSWS–Name (from Unified YSWS Database)"}
        local ships = airtable.list_records("Club Ships", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records
        return ships
    else 
        local ships = airtable.list_records("Club Ships", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"}).records
        return ships
    end
end)

-- MEMBER MANAGEMENT

server:get("/member", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("Name", params.name)
        local fields = {"Name", "club_name", "Email"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields.club_name[1]
        local email = member.fields.Email
        return {name = name, email = email}
    else
        return {error = "Unauthorized"}
    end
end)


server:get("/member/code", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.code == nil then
            return {error = "Missing code parameter"}
        end
        local formula = airtable.safeFormula("Leave Code", params.code)
        local fields = {"Name", "club_name", "Email"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        return {name = member.fields.Name, club_name = member.fields.club_name, email = member.fields.Email}
    else
        return {error = "Unauthorized"}
    end
end)

server:get("/member/email", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.email == nil then
            return {error = "Missing email parameter"}
        end
        local formula = airtable.safeFormula("Email", params.email)
        local fields = {"Name", "club_name"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields.club_name[1]
        return name
    else
        return {error = "Unauthorized"}
    end
end)

server:get("/member/slack", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.slackid == nil then
            return {error = "Missing slackid parameter"}
        end
        local formula = airtable.safeFormula("Slack ID", params.slackid)
        local fields = {"Name", "club_name"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields.club_name[1]
        return name
    else
        return {error = "Unauthorized"}
    end
end)

server:delete("/member", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("Name", params.name)
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local result = airtable.delete_record("Members", member.id)
        if result and result.deleted then
            return {deleted = true, id = result.id}
        else
            return {error = "Failed to delete member"}
        end
    else
        return {error = "Unauthorized"}
    end
end)

server:post("/member", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("Name", params.name)
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local updates = {}
        if params.new_name then
            updates["Name"] = url.strip_quotes(params.new_name)
        end
        if params.new_email then
            updates["Email"] = url.strip_quotes(params.new_email)
        end
        if next(updates) == nil then
            return {error = "No updates provided"}
        end
        local updated = airtable.update_record("Members", member.id, updates)
        if updated then
            return {name = updated.fields.Name, email = updated.fields.Email}
        else
            return {error = "Failed to update member"}
        end
    else
        return {error = "Unauthorized"}
    end
end)

server:post("/member/create", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil or params.email == nil or params.join_code == nil then
            return {error = "Missing required parameters (name, email, join_code)"}
        end
        local fields = {
            ["Name"] = url.strip_quotes(params.name),
            ["Email"] = url.strip_quotes(params.email),
            ["Join Code"] = url.strip_quotes(params.join_code)
        }
        local created = airtable.create_record("Members", fields)
        if created then
            return {id = created.id, name = created.fields.Name, email = created.fields.Email}
        else
            return {error = "Failed to create member"}
        end
    else
        return {error = "Unauthorized"}
    end
end)


server:get("/members", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.club_name == nil then
            return {error = "Missing club_name parameter"}
        end
        local formula = airtable.safeFormula("club_name", params.club_name)
        local fields = {"Members"}
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local memberIds = club.fields.Members
        if memberIds == nil then
            return {members = {}}
        end
        local memberNames = {}
        for _, memberId in ipairs(memberIds) do
            local member = airtable.get_record("Members", memberId)
            table.insert(memberNames, member.fields.Name)
        end
        return {members = memberNames}
    else
        return {error = "Unauthorized"}
    end
end)

-- LEVEL/STATUS MANAGEMENT

server:get("/level", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.club_name == nil then
        return {error = "Missing club_name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.club_name)
    local fields = {"level"}
    local level = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
    if level == nil then
        return {level = "No club found"}
    end
    return {level = level.fields.level}  
end)

server:get("/status", function(req)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.club_name == nil then
        return {error = "Missing club_name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.club_name)
    local fields = {"club_status"}
    local status = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
    if status == nil then
        return {status = "No club found"}
    end
    return {status = status.fields.club_status}  
end)

server:get("/suspension", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.club_name == nil then
            return {error = "Missing club_name parameter"}
        end
        local formula = airtable.safeFormula("club_name", params.club_name)
        local fields = {"club_suspension_status"}
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local suspension_status = club.fields.club_suspension_status or false
        return {club_name = params.club_name, suspended = suspension_status}
    else
        return {error = "Unauthorized"}
    end
end)

server:get("/tokens", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.club_name == nil then
            return {error = "Missing club_name parameter"}
        end
        local formula = airtable.safeFormula("club_name", params.club_name)
        local fields = {"tokens"}
        local club = airtable.list_records("Clubs", "Full Grid", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local tokens = club.fields.tokens or 0
        return {club_name = params.club_name, tokens = tokens}
    else
        return {error = "Unauthorized"}
    end
end)

------------------
-- POST RECORDS --
------------------

-- LEADER MANAGEMENT 

server:post("/leader", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local email = params.email
        local new_email = params.new_email
        if email == nil or new_email == nil then
            return {error = "Missing email"}
        end
        local formula = airtable.safeFormula("email", email)
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula}).records[1]
        if leader == nil then
            return {error = "Leader not found"}
        end
        local id = leader.id
        local updateLeader = airtable.update_record("Leaders", id, {email = url.strip_quotes(new_email)})
        return {new_email = updateLeader.fields.email}
    else 
        return {error = "Unauthorized"}
    end
end)

-- LEVEL/STATUS MANAGEMENT

server:post("/status", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local status = params.status
        local club_name = params.club_name
        if status == nil or club_name == nil then
            return {error = "Missing parameters"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local club = airtable.list_records("Clubs", "Full Grid View", {filterByFormula = formula}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local id = club.id
        local updateClub = airtable.update_record("Clubs", id, {club_status = url.strip_quotes(status)})
        return {new_status = updateClub.fields.club_status}
    else 
        return {error = "Unauthorized"}
    end
end)

server:post("/level", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local level = params.level
        local club_name = params.club_name
        if level == nil or club_name == nil then
            return {error = "Missing parameters"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local club = airtable.list_records("Clubs", "Full Grid View", {filterByFormula = formula}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local id = club.id
        local updateClub = airtable.update_record("Clubs", id, {level = url.strip_quotes(level)})
        return {new_level = updateClub.fields.level}
    else 
        return {error = "Unauthorized"}
    end
end)

server:post("/suspension", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local club_name = params.club_name
        local suspended = params.suspended
        if club_name == nil or suspended == nil then
            return {error = "Missing parameters (club_name, suspended)"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local club = airtable.list_records("Clubs", "Full Grid View", {filterByFormula = formula}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local id = club.id
        local suspendedValue = suspended == "true" or suspended == true
        local updateClub = airtable.update_record("Clubs", id, {club_suspension_status = suspendedValue})
        local newStatus = updateClub.fields.club_suspension_status or false
        return {club_name = club_name, suspended = newStatus}
    else 
        return {error = "Unauthorized"}
    end
end)

server:post("/tokens", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local club_name = params.club_name
        local tokens = params.tokens
        if club_name == nil or tokens == nil then
            return {error = "Missing parameters (club_name, tokens)"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local club = airtable.list_records("Clubs", "Full Grid View", {filterByFormula = formula}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local id = club.id
        local tokensValue = tonumber(tokens)
        if tokensValue == nil then
            return {error = "Invalid tokens value, must be a number"}
        end
        local updateClub = airtable.update_record("Clubs", id, {tokens = tokensValue})
        local newTokens = updateClub.fields.tokens or 0
        return {club_name = club_name, tokens = newTokens}
    else 
        return {error = "Unauthorized"}
    end
end)

-- ANNOUNCEMENT MANAGEMENT

server:post("/announce", function(req)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local club_name = params.club
        local message = params.message
        if club_name == nil or message == nil then
            return {error = "Missing club or message parameter"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local members = airtable.list_records("Members", "Grid view", {filterByFormula = formula}).records
        if members == nil or #members == 0 then
            return {error = "No members found for club"}
        end
        local updated = 0
        for _, member in ipairs(members) do
            airtable.update_record("Members", member.id, {
                ["Annoucement"] = url.strip_quotes(message),
                ["Send Annoucement"] = true
            })
            updated = updated + 1
        end
        return {success = true, membersUpdated = updated}
    else
        return {error = "Unauthorized"}
    end
end)

server.port = os.getenv("PORT")
server.hostname = os.getenv("HOST")
pprint("Server running on port " .. server.port .. " at " .. server.hostname)
server:run()
