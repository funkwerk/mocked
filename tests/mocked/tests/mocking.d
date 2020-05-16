module mocked.tests.mocking;

import dshould;
import mocked;
import std.typecons;
import unit_threaded : ShouldFail;

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

        dependency.identity("Jedes Wort ist ein Vorurtheil").should
            .equal("Jedes Wort ist ein Vorurtheil");
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

@ShouldFail("if an expected method hasn't been called")
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

        dependency.expect.say("Man geht zu Grunde,")
            .returns("wenn man immer zu den Gründen geht.");

        dependency.verify; // FIXME: Must be called on the mocker object.
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
    static assert(is(typeof(Mocker().mock!Dependency)));
}
