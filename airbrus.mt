import "lib/codec" =~ [=> composeCodec :DeepFrozen]
import "lib/codec/utf8" =~ [=> UTF8 :DeepFrozen]
import "irc/client" =~ [=> makeIRCClient :DeepFrozen, => connectIRCClient :DeepFrozen]
import "lib/entropy/entropy" =~ [=> makeEntropy :DeepFrozen]
import "lib/tubes" =~ [=> makePumpTube :DeepFrozen,
                       => makeUTF8DecodePump :DeepFrozen,
                       => makeUTF8EncodePump :DeepFrozen,
                       => makeSplitPump :DeepFrozen,
                       => chain :DeepFrozen]
import "lib/json" =~ [=> JSON :DeepFrozen]
import "lib/help" =~ [=> help :DeepFrozen]
import "lib/words" =~ [=> Word :DeepFrozen]
exports (main)

def chooseAddress(addrs) :NullOk[Bytes] as DeepFrozen:
    for addr in (addrs):
        if (addr.getFamily() == "INET" && addr.getSocketType() == "stream"):
            return addr.getAddress()


def partition(iterable, pred) as DeepFrozen:
    def yes := [].diverge()
    def no := [].diverge()
    for i in (iterable):
        pred(i).pick(yes, no).push(i)
    return [yes.snapshot(), no.snapshot()]


def parseArguments(var argv) as DeepFrozen:
    var channels :List[Str] := []
    var nick :Str := "airbrus"

    while (argv.size() > 0):
        switch (argv):
            match [=="-n", n] + tail:
                traceln(`Using nick '$nick'`)
                nick := n
                argv := tail
            match [channel] + tail:
                traceln(`Adding channel '$channel'`)
                channels with= (channel)
                argv := tail

    return object configuration:
        to channels() :List[Str]:
            return channels

        to nick() :Str:
            return nick


def makeAirbrusHelp(sayer) as DeepFrozen:
    return object airbrusHelp:
        match [verb, args, namedArgs]:
            def s :Str := M.call(help, verb, args, namedArgs)
            for line in (s.split("\n")):
                sayer(line)


def makeDie(entropy) as DeepFrozen:
    return def roll1d20():
        return 1 + entropy.nextInt(20)


def UTF8JSON :DeepFrozen := composeCodec(UTF8, JSON)


def makeLineTube() as DeepFrozen:
    return makePumpTube(makeSplitPump(b`$\n`))


def main(argv, => Timer,
         => currentProcess, => currentRuntime,
         => getAddrInfo,
         => makeFileResource,
         => makeTCP4ClientEndpoint, => makeTCP4ServerEndpoint,
         => unsealException) as DeepFrozen:

    var todoMap :Map[Str, List[Str]] := [].asMap()
    def todoFile := makeFileResource("todo.list")
    def putTodo():
        todoFile.setContents(UTF8JSON.encode(todoMap.snapshot(), null))
    def getTodo():
        def p := todoFile.getContents()
        when (p) ->
            todoMap := UTF8JSON.decode(p, null)
    getTodo()

    def putTodoItem(nick, item):
        def items := todoMap.fetch(nick, fn {[]}).with(item)
        todoMap with= (nick, items)
        putTodo()
    def showTodoItems(name, sayer):
        def items :List[Str] := todoMap.fetch(name, fn {[]})
        if (items.size() == 0):
            sayer(`$name has nothing to do.`)
        else:
            sayer(`$name should do:`)
            for item in (items):
                sayer(`• $item`)
    def removeTodoItem(name, needle, sayer):
        def items := todoMap.fetch(name, fn {[]})
        if (items.size() > 0):
            def [crossedOff,
                 remaining] := partition(items, fn s {s =~ `@_$needle@_`})
            switch (crossedOff):
                match []:
                    sayer(`I'm not seeing it on $name's list…`)
                match [single]:
                    todoMap with= (name, remaining)
                    putTodo()
                    sayer(`Crossed off "$single". Good work!`)
                match several:
                    sayer(`I found a couple things; which one did you mean?`)
                    for item in (several):
                        sayer(`• $item`)
        else:
            sayer(`But $name's list is empty.`)

    def config := parseArguments(argv)

    def nick :Str := config.nick()

    def crypt := currentRuntime.getCrypt()
    def d20 := makeDie(makeEntropy(crypt.makeSecureEntropy()))

    def baseEnv := safeScope | [
        # Superpowers.
        => &&getAddrInfo,
        # Crypto services. Totally safe on IRC; the worst they can do is
        # gently munch on the OS's entropy pool.
        => &&crypt,
        # Some safe conveniences.
        => &&UTF8, => &&JSON, => &&Word,
    ]

    def performEval(text, env, sayer):
        try:
            def [result, newEnv] := eval.evalToPair(text, env)
            # If the result is eventual, then don't say it yet, but set up a
            # callback for when it resolves.
            if (Ref.isResolved(result)):
                sayer(M.toQuote(result))
            else:
                sayer("I'll let you know when that's ready.")
                when (result) ->
                    sayer(`Here you are: ${M.toQuote(result)}`)
                catch problem:
                    def description := M.toQuote(switch (problem) {
                        match via (unsealException) [head, _] {head}
                        match unsealed {unsealed}
                    })
                    sayer(`There was a problem: $description`)
            return newEnv
        catch via (unsealException) [problem, _]:
            sayer(`Exception: $problem`)
            return env

    def userEnvironments := [].asMap().diverge()

    object handler:
        to getNick():
            return nick

        to loggedIn(client):
            for channel in (config.channels()):
                traceln(`Joining #$channel...`)
                client.join(`#$channel`)

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
                # Customize help so that its output doesn't get quoted.
                def brusHelp := makeAirbrusHelp(fn s {client.say(channel, s)})
                def instanceEnv := ["&&help" => &&brusHelp]
                def userEnv := userEnvironments.fetch(user.getNick(),
                                                      fn {baseEnv | instanceEnv})
                def sayer(s :Str):
                    for line in (s.split("\n")):
                        client.say(channel, line)
                def newEnv := performEval(text, userEnv, sayer)
                userEnvironments[user.getNick()] := newEnv

            else if (message =~ `$nick: @action`):
                switch (action):
                    match `speak`:
                        client.say(channel, "Hi there!")

                    match `quit` ? (user.getNick() == "simpson"):
                        client.say(channel, "Okay, bye!")
                        client.quit("ma'a tarci pulce")

                    match `kill`:
                        client.say(channel,
                            `${user.getNick()}: Sorry, I don't know how to do that. Yet.`)

                    match `in @seconds say @utterance`:
                        try:
                            def delta := _makeInt(seconds)
                            when (Timer.fromNow(seconds)) ->
                                client.say(channel,
                                    `${user.getNick()}: "$utterance"`)
                        catch _:
                            client.say(channel,
                                       `${user.getNick()}: Not an integer: $seconds`)

                    match `todo`:
                        showTodoItems(user.getNick(),
                                      fn s {client.say(channel, s)})

                    match `todo @name`:
                        if (name == ""):
                            # They typed "todo ".
                            showTodoItems(user.getNick(),
                                          fn s {client.say(channel, s)})
                        else:
                            showTodoItems(name, fn s {client.say(channel, s)})

                    match `@{var name} should @things`:
                        if (name == "I" || name == "i"):
                            name := user.getNick()
                        putTodoItem(name, things)
                        client.say(channel,
                                   `$name: I've put that on your list.`)

                    match `@{var name} did @needle`:
                        if (name == "I" || name == "i"):
                            name := user.getNick()
                        removeTodoItem(name, needle,
                                       fn s {client.say(channel, s)})

                    match `@stat check`:
                        def roll := d20()
                        def luck := if (roll == 20) {
                            " ☘"
                        } else if (roll == 1) {
                            " ☠"
                        } else { "" }
                        client.say(channel, `$stat check: $roll$luck`)

                    match _:
                        client.say(channel, `${user.getNick()}: I don't understand.`)

    def addrs := getAddrInfo(b`irc.freenode.net`, b``)
    when (addrs) ->
        def address := chooseAddress(addrs)
        if (address == null):
            traceln("Couldn't choose an address to connect to!")

        def client := makeIRCClient(handler, Timer)
        def ep := makeTCP4ClientEndpoint(address, 6667)
        connectIRCClient(client, ep)

    return 0
