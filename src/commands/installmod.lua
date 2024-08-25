return {
    name = "installmod",
    short_description = "Installs a mod from a tarball.",
    usage = "installmod <mod_url>",
    on_call = function(console, args)
        local url = args[1]
        if url == nil then
            console.logger:error("No URL provided")
            return false
        end
        local modInfo = {
            id = "testmod",
            url = url,
            present = false,
            needUpdate = true,
        }
        local result = installModFromTar(modInfo)
        if result == RESULT.SUCCESS then
            console.logger:info("Mod installed successfully")
            return true
        else
            console.logger:error("Error installing mod: ", result)
            return false
        end
    end,
    on_complete = function (console, current_arg)
        return nil
    end
}