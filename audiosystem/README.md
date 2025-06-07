# AudioSystem
This is a audiosystem based off IGModAudioChannel's.<br>
This was originally created for the [SlashCo gamemode](https://github.com/Mantibro/SlashCo/tree/beta-changes/gamemodes/slashco/gamemode/audiosystem) and I now seperated it to provide a standalone version.<br>

> [!NOTE]
> I left a lot of comments in the code, so you can take a look and figure things out.<br>
> I probably won't make a wiki for this or any huge documentation as there is only a hand full of functions which you can use.<br>

Example:
```lua
concommand.Add("test", function()
	local ent = Entity(1):GetEyeTrace().Entity

	AudioSystem.PlaySound({
		soundPath = "somesound.mp3",
		identifier = "ExampleSound",
		volume = 1,
		fadeIn = 2,
		looping = true,
		entity = ent,
		minDistance = 500,
		maxDistance = 1000,
	})

	ent:CallOnRemove("AudioSystem:RemoveSound", function(ent)
		AudioSystem.StopSound("ExampleSound", 1, ent)
	end)
end)
```