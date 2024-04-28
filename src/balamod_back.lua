local back_apply_to_run = back_apply_to_run or Back.apply_to_run  -- luacheck: ignore

function Back:apply_to_run()
    if self.effect.config.cards then
        G.GAME.starting_params.cards = self.effect.config.cards
    end
    back_apply_to_run(self)  -- luacheck: ignore
end
