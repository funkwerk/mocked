module mocked.tests.stub;

import dshould;
import mocked;

@("class can be stubbed")
unittest
{
    static class Dependency
    {
        bool isEven(int number)
        {
            return (number & 1) == 0;
        }
    }
    Mocker mocker;
    auto stubbed = mocker.stub!Dependency;

    stubbed.stub.isEven(6).returns(false);
    stubbed.stub.isEven(5).returns(true);

    Dependency dependency = stubbed.get;

    dependency.isEven(5).should.equal(true);
    dependency.isEven(6).should.equal(false);
}

@("stubs classes with an constructor")
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
    auto dependency = Mocker().stub!Dependency("Alea iacta est.");

    dependency.stub.saySomething().passThrough;

    dependency.saySomething().should.equal("Alea iacta est.");
}

@("can use custom comparator")
unittest
{
    import std.math : fabs;

    static class Dependency
    {
        public bool call(float)
        {
            return false;
        }
    }

    alias approxComparator = (float a, float b) {
        return fabs(a - b) <= 0.1;
    };
    auto mocker = configure!(Comparator!approxComparator);
    auto builder = mocker.stub!Dependency;

    builder.stub.call(1.01).returns(true);

    auto stub = builder.get;

    stub.call(1.02).should.be(true);
}

@("stubs const methods")
unittest
{
    interface I
    {
        public bool isI(string) const;
    }
    Mocker mocker;

    static assert(is(typeof(mocker.stub!I())));
}
