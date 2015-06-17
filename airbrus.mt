def [=> strToInt] | _ := import("lib/atoi")
def [=> makeIRCClient, => connectIRCClient] := import("lib/irc/client",
    [=> Timer])
def [=> elementsOf] | _ := import("fun/elements")

def nick :Str := "airbrus"

def environment := [
    => null, => true, => false,
    => __makeList, __makeOrderedSpace, => __makeString, => __equalizer,
    => __comparer,
    => __accumulateList, => __accumulateMap,
    => Any, => Bool, => Char, => DeepFrozen, => Double, => Empty, => Int,
    => List, => Map, => NullOk, => Same, => Set, => Str, => SubrangeGuard,
    => Void,
    => __mapEmpty, => __mapExtract,
    => __booleanFlow, => __iterWhile, => __validateFor,
    => __switchFailed, => __makeVerbFacet,
    => __suchThat, => __matchSame, => __bind, => __quasiMatcher,
    # Superpowers. Things we don't want to include:
    # * import
    => M, => simple__quasiParser, => throw,
]

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
        if (message =~ `> @text`):
            try:
                def result := eval(text, environment)
                for line in `$result`.split("\n"):
                    client.say(channel, line)
            catch problem:
                for line in `$problem`.split("\n"):
                    client.say(channel, line)

        else if (message =~ `!@action @text`):
            switch (action):
                match =="parse":
                    def parser := makeMonteParser()
                    parser.feedMany(text)
                    if (parser.failed()):
                        def failure := parser.getFailure()
                        client.say(channel, `Parse failure: $failure`)
                    else:
                        def result := parser.results()[0]
                        client.say(channel, `$result`)

                match _:
                    pass

        else if (message =~ `$nick: @action`):
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
                        def users := [for k => _ in (client.getUsers(otherChannel, ej)) k]
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
