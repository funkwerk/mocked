module mocked.tests.mocking;

import dshould;
import mocked;
import std.typecons;

@("mocks functions with one argument")
unittest
{
    static class Dependency
    {
        string call(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.call("Noch ein Jahrhundert Zeitungen")
            .returns("und alle Worte stinken");

        dependency.call("Noch ein Jahrhundert Zeitungen").should
            .equal("und alle Worte stinken");
    }
}

@("mocks functions without arguments")
unittest
{
    enum int expected = 10;

    with (Mocker())
    {
        auto dependency = mock!Object;

        dependency.expect.toHash.returns(expected);

        dependency.toHash.should.equal(expected);
    }
}

@("mocks overloaded functions")
unittest
{
    static class Dependency
    {
        int call(int number)
        {
            return number;
        }

        string call(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.call("Die beste Maske, die wir tragen")
            .returns("ist unser eigenes Gesicht");

        dependency.call("Die beste Maske, die wir tragen").should
            .equal("ist unser eigenes Gesicht");
    }
}

@("mocks overloaded functions with the same return type")
unittest
{
    static class Dependency
    {
        string call(char character)
        {
            return [character];
        }

        string call(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.call("Wenn dein Werk den Mund aufthut")
            .returns("sollst du selber das Maul halten");

        dependency.call("Wenn dein Werk den Mund aufthut").should
            .equal("sollst du selber das Maul halten");
    }
}

@("keeps original behavior")
unittest
{
    static class Dependency
    {
        string identity(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.identity("Jedes Wort ist ein Vorurtheil.")
            .passThrough;

        dependency.identity("Jedes Wort ist ein Vorurtheil.").should
            .equal("Jedes Wort ist ein Vorurtheil.");
    }
}

@("ignores arguments")
unittest
{
    static class Dependency
    {
        string identity(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.identity.returns("die nicht durch das Glas kann");

        dependency.identity("Die Fliege").should
            .equal("die nicht durch das Glas kann");
    }
}

@("ignores final functions")
unittest
{
    static class Dependency
    {
        final string say(string)
        {
            return "Die Alten lasen laut.";
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.say(null).should.equal("Die Alten lasen laut.");
    }
}

@("mocks functions with two arguments")
unittest
{
    static class Dependency
    {
        string say(string, string)
        {
            return null;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.say("Derselbe Text", "erlaubt unzählige Auslegungen:")
            .returns(q{es giebt keine "richtige" Auslegung.});

        dependency.say("Derselbe Text", "erlaubt unzählige Auslegungen:").should
            .equal(q{es giebt keine "richtige" Auslegung.});
    }
}

@("checks consecutive calls")
unittest
{
    static class Dependency
    {
        string say(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.say(q{Die "wahre Welt",})
            .returns("wie immer auch man sie bisher concipirt hat, -");

        dependency.expect.say("sie war immer")
            .returns("die scheinbare Welt noch einmal.");

        dependency.say(q{Die "wahre Welt",}).should
            .equal("wie immer auch man sie bisher concipirt hat, -");

        dependency.say("sie war immer").should
            .equal("die scheinbare Welt noch einmal.");
    }
}

@("mocks classes with constructors")
unittest
{
    static class Dependency
    {
        string phrase;

        public this(string phrase)
        {
            this.phrase = phrase;
        }

        public string saySomething()
        {
            return this.phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency("Alea iacta est.");

        dependency.expect.saySomething().passThrough;

        dependency.saySomething().should.equal("Alea iacta est.");
    }
}

@("mocks void functions")
unittest
{
    static class Dependency
    {
        void method()
        {
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
}

@("mocks classes with overloaded constructors")
unittest
{
    import std.string : join, outdent, strip;

    static class Dependency
    {
        string phrase;

        public this(string phrase)
        {
            this.phrase = phrase;
        }

        public this(string part1, string part2)
        {
            this.phrase = [part1, part2].join('\n');
        }

        public string say()
        {
            return this.phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency("Kaum seid ihr geboren,",
                "so fangt ihr auch schon an zu sterben.");

        dependency.expect.say().passThrough;

        dependency.say.should.equal(r"
                Kaum seid ihr geboren,
                so fangt ihr auch schon an zu sterben.
                ".outdent.strip);
    }
}

@("allows to disable the constructor")
unittest
{
    static class Dependency
    {
        public this(string)
        {
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
}

@("allows arbitrary actions")
unittest
{
    enum string expected = "Nihil est in intellectu, quod non prius fuerit in sensibus";
    static class Dependency
    {
        void setPhrase()
        {
        }
    }

    string phrase;
    Mocker mocker;
    auto dependency = mocker.mock!Dependency();

    dependency.expect.setPhrase().action(() {
        phrase = expected;
    });

    dependency.setPhrase();

    phrase.should.equal(expected);
}

@("propagates the value returned by an action")
unittest
{
    enum string expected = "Auf seine Fehler säen.";
    static class Dependency
    {
        string phrase()
        {
            return null;
        }
    }

    Mocker mocker;
    auto dependency = mocker.mock!Dependency;

    dependency.expect.phrase().action(() => expected);

    dependency.phrase.should.equal(expected);
}

@(".action inherits nothrow from the mocked method")
unittest
{
    static class Dependency
    {
        void act() pure @safe
        {
        }
    }
    alias action = () pure @safe {
        throw new Exception("Von sich absehen ist nöthig um gut - zu sehen.");
    };
    Mocker mocker;
    auto dependency = mocker.mock!Dependency;

    static assert(is(typeof(dependency.expect.act().action(action))));
}

@("arguments can be const objects")
unittest
{
    interface A
    {
        void func(const Object);
    }
    Mocker mocker;

    mocker.mock!A();
}

@("supports struct with immutable members as arguments")
unittest
{
    static struct S
    {
        private immutable string s;
    }
    static class Dependency
    {
        void withDefaultParameter(S)
        {
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
}

@("supports immutable struct as return value")
unittest
{
    static immutable struct S
    {
        private string s;
    }
    static class Dependency
    {
        S method()
        {
            return S("");
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
}

@("supports default parameters")
unittest
{
    enum string expected = "simplex sigillum veri";

    static class Dependency
    {
        void say(string = expected)
        {
        }
    }
    Mocker mocker;

    auto mocked = mocker.mock!Dependency;

    mocked.expect.say();

    mocked.say(expected);
}

@("can mock functions with more than 2 parameters")
unittest
{
    static class Dependency
    {
        void say(string, string, string)
        {
        }
    }
    Mocker mocker;
    static assert(is(typeof(mocker.mock!Dependency())));
}

@("can mock a method with an internal name")
unittest
{
    static class Dependency
    {
        void repository()
        {
        }
        void call()
        {
        }
        void calls()
        {
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
}

@("can mock a method returning a struct with const members")
unittest
{
    struct Split
    {
        const string split;
    }

    static class Dependency
    {
        Split f()
        {
            return Split();
        }
    }
    static assert(is(typeof(Mocker().mock!Dependency())));
    static assert(is(typeof(Mocker().stub!Dependency())));
}

@("mocks method with a parameter called 'call'")
unittest
{
    static class Dependency
    {
        void foo(int call)
        {
        }
    }
    Mocker().mock!Dependency();
    static assert(is(typeof(Mocker().stub!Dependency())));
}

@("mocks interfaces with const @safe methods")
unittest
{
    interface Test
    {
        int value() const @safe;
    }

    Mocker mocker;
    auto mock = mocker.mock!Test;
    mock.expect.value().returns(5);

    assert(mock.value() == 5);
}
