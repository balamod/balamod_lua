local balalib = require("balalib")

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
        local result = balalib.install_mod_from_url(url)
        if result.mod_id then
            console.logger:info("Mod ", result.mod_id, "installed successfully")
            return true
        else
            console.logger:error("Error installing mod: ", result.error)
            return false
        end
    end,
    on_complete = function (console, current_arg)
        return nil
    end
}
