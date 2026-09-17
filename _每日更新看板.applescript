on run
	set projectRoot to "/Users/edy/Desktop/风灵看板复用/风灵看板复用包"
	set cmdFile to projectRoot & "/每日更新看板.command"
	tell application "Terminal"
		activate
		do script "bash " & quoted form of cmdFile
	end tell
end run
