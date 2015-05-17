def [=> strToInt] | _ := import("lib/atoi")
def [=> makeIRCClient, => connectIRCClient] := import("lib/irc/client",
    [=> Timer])
def [=> elementsOf] | _ := import("fun/elements")

def nick :Str := "airbrus"

object handler:
    to getNick():
        return nick

    to loggedIn(client):
        client.join("#montebot")
        client.join("#monte")

    to ctcp(client, user, message):
        switch (message):
            match =="VERSION":
                def name := "Airbrus"
                def version := "0.0.1"
                def environment := "Written in Monte, running on Typhon"
                client.ctcp(user.getNick(), `VERSION $name ($version): $environment`)
            match =="SOURCE":
                def url := "https://github.com/MostAwesomeDude/airbrus"
                client.ctcp(user.getNick(), `SOURCE $url`)

            match _:
                traceln(`Unknown CTCP $message`)

    to privmsg(client, user, channel, message):
        traceln("privmsg", client, user, channel, message)
        if (message =~ `$nick: @action`):
            switch (action):
                match `join @newChannel`:
                    client.say(channel, "Okay, joining " + newChannel)
                    client.join(newChannel)

                match `speak`:
                    client.say(channel, "Hi there!")

                match `quit`:
                    client.say(channel, "Okay, bye!")
                    client.quit("ma'a tarci pulce")

                match `kill`:
                    client.say(channel,
                        `${user.getNick()}: Sorry, I don't know how to do that. Yet.`)

                match `list @otherChannel`:
                    escape ej:
                        def users := [k
                            for k => _ in client.getUsers(otherChannel, ej)]
                        client.say(channel, " ".join(users))
                    catch _:
                        client.say(channel, `I can't see into $otherChannel`)

                match `in @{via (strToInt) seconds} say @utterance`:
                    when (Timer.fromNow(seconds)) ->
                        client.say(channel,
                            `${user.getNick()}: Alarm: "$utterance"`)

                match `elements @word`:
                    client.say(channel, `Elements: ${elementsOf(word)}`)

                match _:
                    client.say(channel, `${user.getNick()}: I don't understand.`)

def client := makeIRCClient(handler)
def ep := makeTCP4ClientEndpoint("irc.freenode.net", 6667)
connectIRCClient(client, ep)
