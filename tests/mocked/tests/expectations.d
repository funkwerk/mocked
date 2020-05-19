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
