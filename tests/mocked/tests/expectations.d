module mocked.tests.expectations;

import dshould;
import mocked;
import unit_threaded : ShouldFail;

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
    }
}

@("repeats expectations infinitely")
unittest
{
    enum expected = "Piscis primum a capite foetat";

    Mocker mocker;

    auto mock = mocker.mock!Object;

    mock.expect.toString().returns(expected).repeatAny;

    Object object = mock.getMock;

    object.toString.should.equal(expected);
    object.toString.should.equal(expected);

    mocker.verify;
}

@("prints arguments in the unexpected call error message")
unittest
{
    static class Dependency
    {
        void say(string phrase1, string phrase2)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency.getMock;

    mock.say("Ton der Jugend", "zu laut.")
        .should
        .throwAn!UnexpectedCallError
        .where
        .toString
        .should
        .equal(`Unexpected call: Dependency.say("Ton der Jugend", "zu laut.")`);
}

@("throws once")
unittest
{
    static class Dependency
    {
        void say(string phrase)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say("Die Ängstlichkeit vergiftet die Seele.").repeat(2);

    mocker.verify.should.throwAn!ExpectationViolationException;
    mocker.verify.should.not.throwAn!ExpectationViolationException;
}

@("gives multiline error messages on mismatched arguments")
unittest
{
    static class Dependency
    {
        void say(string phrase)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say("Let's eat, grandma!").repeat(2);

    mock.say("Let's eat grandma!")
        .should.throwAn!UnexpectedArgumentError
        .where.toString.should.contain.any("\n");
}
