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

server:get("/clubs", function(req, res)
    return {totalClubs = airtable.count_records("Clubs")}
end)

server:get("/clubs/map", function(req, res)
    log.request(req:uri(), req:headers())
    res:set_header("Access-Control-Allow-Origin", "*")
    local fields = {"club_name", "venue_lat_fuzz", "venue_lng_fuzz", "status", "club_website"}
    local result = {}
    local offset = nil
    repeat
        local data = airtable.list_records("Map", nil, {fields = fields, offset = offset, base_id = "app3sG13yVpMwree2"})
        if data and data.records then
            for _, club in ipairs(data.records) do
                local clubFields = {
                    club_name = club.fields.club_name,
                    venue_lat_fuzz = club.fields.venue_lat_fuzz,
                    venue_lng_fuzz = club.fields.venue_lng_fuzz,
                    status = club.fields.status
                }
                if club.fields.club_website then
                    clubFields.club_website = club.fields.club_website
                end
                table.insert(result, {
                    id = club.id,
                    fields = clubFields
                })
            end
            offset = data.offset
        else
            offset = nil
        end
    until not offset
    return result
end)

server:get("/clubs/country", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.country == nil then
        return {error = "Missing country parameter"}
    end
    local formula = airtable.safeFormula("venue_addr_country", params.country)
    return {clubs  = airtable.count_records("Clubs", formula)}
end)


server:get("/club/code", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.code == nil then
            return {error = "Missing code parameter"}
        end
        local formula = airtable.safeFormula("join_code", params.code)
        local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        return club
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:get("/club", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.name == nil then
        return {error = "Missing name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.name)
    if auth.checkRead(req:headers().authorization) then
        local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"}).records[1]
        if club == nil then
            return {club_name = nil}
        end
        return club
    else
        local fields = {"club_name", "status", "club_website"}
        local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {club_name = nil}
        end
        return {
            id = club.id,
            fields = {
                club_name = club.fields.club_name,
                status = club.fields.status,
                club_website = club.fields.club_website
            }
        }
    end
end)

server:get("/club/ambassador", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.name == nil then
        return {error = "Missing name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.name)
    local fields = {"rel_ambassador"}
    local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
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

server:get("/leader", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.email == nil then
        return {error = "Missing email parameter"}
    end
    local formula = airtable.safeFormula("contact_email", params.email)
    local fields = {"rel_clubs"}
    if auth.checkRead(req:headers().authorization) then
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        local club = nil
        if leader == nil then
            return {club_name = nil}
        end
        if leader.fields.rel_clubs then
            club = leader.fields.rel_clubs[1]
        end
        local clubfields = airtable.get_record("Clubs", club).fields
        local club_name = clubfields.club_name
        local club_status = clubfields.status
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

server:get("/leader/slack", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.slackid == nil then
        return {error = "Missing slackId parameter"}
    end
    local formula = airtable.safeFormula("contact_slack", params.email)
    local fields = {"rel_clubs"}
    if auth.checkRead(req:headers().authorization) then
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        local club = nil
        if leader == nil then
            return {club_name = nil}
        end
        if leader.fields.rel_clubs then
            club = leader.fields.rel_clubs[1]
        end
        local clubfields = airtable.get_record("Clubs", club).fields
        local club_name = clubfields.club_name
        local club_status = clubfields.status
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

server:get("/ships", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.club_name == nil then
            return {error = "Missing club_name parameter"}
        end
        local formula = airtable.safeFormula("club_name", params.club_name)
        local ships = airtable.list_records("Ships", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"}).records
        return ships
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

-- MEMBER MANAGEMENT

server:get("/member/ships", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.email == nil then
            return {error = "Missing email parameter"}
        end
        local formula = airtable.safeFormula("email", params.email)
        local ships = airtable.list_records("Ships", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"}).records
        return ships
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:get("/member", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("name", params.name)
        local fields = {"name", "club_name (from rel_club)", "email"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields["club_name (from rel_club)"][1]
        local email = member.fields.email
        return {name = name, email = email}
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)


server:get("/member/code", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.code == nil then
            return {error = "Missing code parameter"}
        end
        local formula = airtable.safeFormula("leave_code", params.code)
        local fields = {"name", "club_name (from rel_club)", "email"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        return {name = member.fields.Name, club_name = member.fields["club_name (from rel_club)"], email = member.fields.Email}
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:get("/member/email", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.email == nil then
            return {error = "Missing email parameter"}
        end
        local formula = airtable.safeFormula("email", params.email)
        local fields = {"name", "club_name (from rel_club)"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields["club_name (from rel_club)"][1]
        return name
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:get("/member/slack", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.slackid == nil then
            return {error = "Missing slackid parameter"}
        end
        local formula = airtable.safeFormula("contact_slack", params.slackid)
        local fields = {"name", "club_name (from rel_club)"}
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local name = member.fields["club_name (from rel_club)"][1]
        return name
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:delete("/member", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("name", params.name)
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
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:post("/member", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil then
            return {error = "Missing name parameter"}
        end
        local formula = airtable.safeFormula("name", params.name)
        local member = airtable.list_records("Members", "Grid view", {filterByFormula = formula}).records[1]
        if member == nil then
            return {error = "Member not found"}
        end
        local updates = {}
        if params.new_name then
            updates["name"] = url.strip_quotes(params.new_name)
        end
        if params.new_email then
            updates["email"] = url.strip_quotes(params.new_email)
        end
        if next(updates) == nil then
            return {error = "No updates provided"}
        end
        local updated = airtable.update_record("Members", member.id, updates)
        if updated then
            return {name = updated.fields.name, email = updated.fields.email}
        else
            return {error = "Failed to update member"}
        end
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:post("/member/create", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.name == nil or params.email == nil or params.join_code == nil then
            return {error = "Missing required parameters (name, email, join_code)"}
        end
        local clean_join_code = url.strip_quotes(params.join_code)
        local formula = airtable.safeFormula("join_code", clean_join_code)
        local clubData = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York"})
        if not clubData or not clubData.records or #clubData.records == 0 then
            return {error = "Club not found with matching join code"}
        end
        local club_id = clubData.records[1].id

        local fields = {
            ["name"] = url.strip_quotes(params.name),
            ["email"] = url.strip_quotes(params.email),
            ["rel_club"] = { club_id }
        }
        local created = airtable.create_record("Members", fields)
        if created then
            return {id = created.id, name = created.fields.name, email = created.fields.email}
        else
            return {error = "Failed to create member"}
        end
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)


server:get("/members", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        if params.club_name == nil then
            return {error = "Missing club_name parameter"}
        end
        local formula = airtable.safeFormula("club_name", params.club_name)
        local fields = {"rel_members"}
        local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local memberIds = club.fields.rel_members
        if memberIds == nil then
            return {members = {}}
        end
        local memberNames = {}
        for _, memberId in ipairs(memberIds) do
            local member = airtable.get_record("Members", memberId)
            table.insert(memberNames, member.fields.name)
        end
        return {members = memberNames}
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

--  STATUS MANAGEMENT

server:get("/status", function(req, res)
    log.request(req:uri(), req:headers())
    local params = url.parse_query(req:uri())
    if params.club_name == nil then
        return {error = "Missing club_name parameter"}
    end
    local formula = airtable.safeFormula("club_name", params.club_name)
    local fields = {"status"}
    local status = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula, timeZone = "America/New_York", fields = fields}).records[1]
    if status == nil then
        return {status = "No club found"}
    end
    return {status = status.fields.status}  
end)


------------------
-- POST RECORDS --
------------------

-- LEADER MANAGEMENT 

server:post("/leader/change", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local club_name = params.club
        local new_email = params.new_email
        local old_email = params.old_email
        
        if club_name == nil or new_email == nil or old_email == nil then
            return {error = "Missing parameters (club, new_email, old_email)"}
        end
        
        local club_name_clean = url.strip_quotes(club_name)
        local new_email_clean = url.strip_quotes(new_email)
        local old_email_clean = url.strip_quotes(old_email)

        -- 1. Find the club to link
        local clubFormula = airtable.safeFormula("club_name", club_name_clean)
        local clubData = airtable.list_records("Clubs", "Grid view", {filterByFormula = clubFormula})
        if not clubData or not clubData.records or #clubData.records == 0 then
            return {error = "Club not found"}
        end
        local club_id = clubData.records[1].id

        -- 2. Create the new leader record linked to the club
        local new_leader_fields = {
            ["contact_email"] = new_email_clean,
            ["rel_clubs"] = { club_id }
        }
        local created_leader = airtable.create_record("Leaders", new_leader_fields)
        if not created_leader then
            return {error = "Failed to create new leader record"}
        end

        -- 3. Clear the old leader's club relations
        local oldFormula = airtable.safeFormula("contact_email", old_email_clean)
        local oldData = airtable.list_records("Leaders", "Grid view", {filterByFormula = oldFormula})
        if oldData and oldData.records and #oldData.records > 0 then
            airtable.update_record("Leaders", oldData.records[1].id, {
                ["rel_clubs"] = {}
            })
        end

        return {
            success = true,
            new_leader_id = created_leader.id,
        }
    else 
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server:post("/leader", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local email = params.email
        local new_email = params.new_email
        if email == nil or new_email == nil then
            return {error = "Missing email"}
        end
        local formula = airtable.safeFormula("contact_email", email)
        local leader = airtable.list_records("Leaders", "Grid view", {filterByFormula = formula}).records[1]
        if leader == nil then
            return {error = "Leader not found"}
        end
        local id = leader.id
        local updateLeader = airtable.update_record("Leaders", id, {contact_email = url.strip_quotes(new_email)})
        return {new_email = updateLeader.fields.contact_email}
    else 
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

-- LEVEL/STATUS MANAGEMENT

server:post("/status", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local status = params.status
        local club_name = params.club_name
        if status == nil or club_name == nil then
            return {error = "Missing parameters"}
        end
        local formula = airtable.safeFormula("club_name", club_name)
        local club = airtable.list_records("Clubs", "Grid view", {filterByFormula = formula}).records[1]
        if club == nil then
            return {error = "Club not found"}
        end
        local id = club.id
        local updateClub = airtable.update_record("Clubs", id, {status = url.strip_quotes(status)})
        return {new_status = updateClub.fields.status}
    else 
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)
    


-- ANNOUNCEMENT MANAGEMENT

server:post("/announce", function(req, res)
    log.request(req:uri(), req:headers())
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        local club_name = params.club
        local message = params.message
        if club_name == nil or message == nil then
            return {error = "Missing club or message parameter"}
        end
        local base_id = "appLl9fqi9xsugq6Y"
        local formula = airtable.safeFormula("club_name (from rel_club)", club_name)
        local members = airtable.list_records("Members", "Grid view", {filterByFormula = formula, base_id = base_id}).records
        if members == nil or #members == 0 then
            return {error = "No members found for club"}
        end
        local updated = 0
        for _, member in ipairs(members) do
            airtable.update_record("Members", member.id, {
                ["annoucement"] = url.strip_quotes(message),
                ["send_annoucement"] = true
            }, base_id)
            updated = updated + 1
        end
        return {success = true, membersUpdated = updated}
    else
        res:set_status_code(403)
        return {error = "Unauthorized"}
    end
end)

server.port = os.getenv("PORT")
server.hostname = os.getenv("HOST")
print("Server running on port " .. server.port .. " at " .. server.hostname)
server:run()
