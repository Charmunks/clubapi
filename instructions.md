# Adding New API Routes

This guide explains how to add new routes to the Clubs API.

## Step 1: Add the Route to server.lua

Add your route handler in [server.lua](server.lua) in the appropriate section (GET or POST):

### GET Route Example
```lua
server:get("/your-route", function(req)
    log.request(req:uri(), req:headers())
    
    -- Check authentication if needed
    if auth.checkRead(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        
        -- Validate required parameters
        if params.required_param == nil then
            return {error = "Missing required_param parameter"}
        end
        
        -- Query Airtable
        local formula = airtable.safeFormula("field_name", params.required_param)
        local fields = {"field1", "field2"}
        local record = airtable.list_records("Table Name", "View Name", {
            filterByFormula = formula,
            timeZone = "America/New_York",
            fields = fields
        }).records[1]
        
        if record == nil then
            return {error = "Record not found"}
        end
        
        return {data = record.fields}
    else
        return {error = "Unauthorized"}
    end
end)
```

### POST Route Example
```lua
server:post("/your-route", function(req)
    log.request(req:uri(), req:headers())
    
    -- Check write permissions
    if auth.checkWrite(req:headers().authorization) then
        local params = url.parse_query(req:uri())
        
        -- Validate parameters
        if params.id == nil or params.new_value == nil then
            return {error = "Missing parameters"}
        end
        
        -- Update record
        local updated = airtable.update_record("Table Name", params.id, {
            field_name = url.strip_quotes(params.new_value)
        })
        
        if updated then
            return {success = true, data = updated.fields}
        else
            return {error = "Failed to update record"}
        end
    else
        return {error = "Unauthorized"}
    end
end)
```

## Step 2: Authentication Functions

Use the appropriate auth function based on required permissions:

- **`auth.checkRead(apikey)`** - Allows `admin`, `read`, or `write` permissions
- **`auth.checkWrite(apikey)`** - Allows `admin` or `write` permissions  
- **`auth.checkAdmin(apikey)`** - Allows only `admin` permissions

Example:
```lua
if auth.checkRead(req:headers().authorization) then
    -- Protected logic here
else
    return {error = "Unauthorized"}
end
```

## Step 3: Airtable Functions

### Query Records
```lua
-- Create a safe formula (prevents injection)
local formula = airtable.safeFormula("field_name", value)

-- List records with filtering
local result = airtable.list_records("Table Name", "View Name", {
    filterByFormula = formula,
    timeZone = "America/New_York",
    fields = {"field1", "field2"},  -- Optional: limit returned fields
    offset = offset  -- Optional: for pagination
})
```

### Get Single Record
```lua
local record = airtable.get_record("Table Name", "record_id")
```

### Create Record
```lua
local created = airtable.create_record("Table Name", {
    field1 = "value1",
    field2 = "value2"
})
```

### Update Record
```lua
local updated = airtable.update_record("Table Name", "record_id", {
    field1 = "new_value"
})
```

### Delete Record
```lua
local deleted = airtable.delete_record("Table Name", "record_id")
```

## Step 4: URL Parameter Handling

```lua
-- Parse query parameters from URL
local params = url.parse_query(req:uri())

-- Access parameters
local value = params.parameter_name

-- Strip quotes from values before using in Airtable
local clean_value = url.strip_quotes(params.parameter_name)
```

## Step 5: Document in OpenAPI

Add your route to [openapi.yaml](openapi.yaml) with proper documentation:

```yaml
  /your-route:
    get:
      summary: Brief description
      description: Detailed description of what this endpoint does. Include permission requirements.
      security:
        - ApiKeyAuth: []  # If authentication required
      parameters:
        - in: query
          name: parameter_name
          schema:
            type: string
          required: true
          description: Description of the parameter
          example: "Example Value"
      responses:
        '200':
          description: Success response
          content:
            application/json:
              schema:
                type: object
                properties:
                  field_name:
                    type: string
                    example: "example value"
        '400':
          description: Bad request
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string
                    example: "Missing parameter_name parameter"
        '401':
          description: Unauthorized
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string
                    example: "Unauthorized"
```

### Important OpenAPI Notes:
- Use `security: []` for public endpoints (no auth)
- Use `security: - ApiKeyAuth: []` for protected endpoints
- Always add `example` values to parameters and responses
- Include all possible error responses (400, 401, 404, etc.)

## Step 6: Testing Your Route

1. **Restart the server**:
   ```bash
   pkill -f "astra run server.lua"
   astra run server.lua
   ```

2. **Test with curl**:
   ```bash
   # GET request
   curl "http://localhost:3000/your-route?param=value" \
     -H "Authorization: your_api_key"
   
   # POST request
   curl -X POST "http://localhost:3000/your-route?param=value" \
     -H "Authorization: your_api_key"
   ```

3. **Test in the documentation**:
   - Open the docs at `http://localhost:3000`
   - Find your endpoint
   - Use the "Try It" feature with your API key

## Common Patterns

### Checkbox Fields (Boolean)
```lua
-- Reading
local is_checked = record.fields.checkbox_field or false

-- Writing
local checkbox_value = params.value == "true" or params.value == true
airtable.update_record("Table", record_id, {
    checkbox_field = checkbox_value
})
```

### Pagination
```lua
local result = {}
local offset = nil
repeat
    local data = airtable.list_records("Table", "View", {
        fields = fields,
        offset = offset
    })
    if data and data.records then
        for _, record in ipairs(data.records) do
            table.insert(result, record)
        end
        offset = data.offset
    else
        offset = nil
    end
until not offset
```

### Error Handling
```lua
-- Always check for nil results
if record == nil then
    return {error = "Record not found"}
end

-- Check for required parameters
if params.required_param == nil then
    return {error = "Missing required_param parameter"}
end
```

## Code Organization

- **GET routes** go in the "GET RECORDS" section
- **POST routes** go in the "POST RECORDS" section
- Group related routes together (e.g., all club routes, all member routes)
- Add section comments like `-- FEATURE MANAGEMENT` for clarity

## Best Practices

1. **Always log requests**: Start handlers with `log.request(req:uri(), req:headers())`
2. **Validate input**: Check for required parameters before processing
3. **Use safe formulas**: Always use `airtable.safeFormula()` to prevent injection
4. **Strip quotes**: Use `url.strip_quotes()` for user input going to Airtable
5. **Handle nulls**: Check for `nil` values from Airtable queries
6. **Consistent errors**: Return `{error = "message"}` format for all errors
7. **Set timezone**: Include `timeZone = "America/New_York"` in Airtable queries
8. **Add examples**: Include example values in OpenAPI documentation

## Example: Complete Route Implementation

See the `/suspension` routes in [server.lua](server.lua) and [openapi.yaml](openapi.yaml) for a complete example of:
- GET endpoint with authentication
- POST endpoint with checkbox field handling
- Full OpenAPI documentation with examples
- Proper error handling and validation
