module mocked.tests.readme;

unittest
{
    import mocked;

    static class Dependency
    {
        string authorOf(string phrase)
        {
            return null;
        }
    }

    enum string phrase = "[T]he meaning of a word is its use in the language.";
    enum string expected = "L. Wittgenstein";

    Mocker mocker;
    auto builder = mocker.mock!Dependency;

    builder.expect
        .authorOf("[T]he meaning of a word is its use in the language.")
        .returns(expected);

    auto dependency = builder.getMock;

    assert(dependency.authorOf(phrase) == expected);
}
