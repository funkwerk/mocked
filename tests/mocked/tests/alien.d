module mocked.tests.alien;

import dshould;
import mocked;
import unit_threaded : DontTest, ShouldFail;

version (unittest)
{
    class Templated(T)
    {
    }

    interface IM
    {
        void bar();
    }

    class ConstructorArg
    {
        int a;

        this(int i)
        {
            this.a = i;
        }

        int getA()
        {
            return this.a;
        }
    }

    class SimpleObject
    {
        this()
        {
        }

        void print()
        {
            import std.stdio : writeln;

            writeln(toString());
        }
    }

    interface IRM
    {
        IM get();
        void set(IM im);
    }

    interface IFace
    {
        void foo(string s);
    }

    class Smthng : IFace
    {
        void foo(string)
        {
        }
    }

    class HasMember
    {
        int member;
    }

    class Overloads
    {
        void foo()
        {
        }

        void foo(int)
        {
        }
    }

    interface VirtualFinal
    {
        int makeVir();
    }

    class Dependency
    {
        private int[] arr = [1, 2];
        private int index = 0;
        public int foo()
        {
            return arr[index++];
        }
    }

    class TakesFloat
    {
        public void foo(float)
        {
        }
    }

    @DontTest
    class TestClass
    {
        string test()
        {
            return "test";
        }

        string test1()
        {
            return "test 1";
        }

        string test2()
        {
            return "test 2";
        }

        int test_int(int i)
        {
            return i;
        }
    }
}

@("nontemplated mock")
unittest
{
    Mocker().mock!(Object)();
}

@("templated mock")
unittest
{
    static assert(is(typeof(Mocker().mock!(Templated!(int))())));
}

@("interface mock")
unittest
{
    static assert(is(typeof(Mocker().mock!IM())));
}

@("constructor argument")
unittest
{
    Mocker mocker;

    static assert(is(typeof(mocker.mock!(ConstructorArg)(4))));
}

@("unexpected call")
unittest
{
    Mocker mocker;
    TestClass cl = mocker.mock!(TestClass);

    cl.test.should.throwA!UnexpectedCallError;
    mocker.verify;
}

@ShouldFail("expect")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().repeat(0).returns("mrow?");

    cl.test;
}

@("repeat single")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().repeat(2).returns("foom?");

    cl.test;
    cl.test;

    cl.test.should.throwAn!UnexpectedCallError;
}

@ShouldFail("repository match counts")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!TestClass;

    cl.expect.test().repeat(2).returns("mew.");

    mocker.verify();
}

@("delegate payload")
unittest
{
    bool calledPayload = false;
    Mocker mocker;
    auto obj = mocker.mock!SimpleObject;

    obj.expect.print().action({ calledPayload = true; });

    obj.print;

    calledPayload.should.be(true);
}

@("delegate payload with mismatching parameters")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!SimpleObject;

    static assert(!is(typeof(obj.expect.print().action((int) {}))));
}

@("exception payload")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(SimpleObject);

    enum string msg = "divide by cucumber error";
    obj.expect.print().throws(new Exception(msg));

    obj.print.should.throwAn!Exception.where.msg.should.equal(msg);
}

@("passthrough")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().passThrough;

    string str = cl.test;
    str.should.equal("test");
}

@("class with constructor init check")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!ConstructorArg(4);

    obj.expect.getA().passThrough;

    obj.getA().should.equal(4);
}

@("associative arrays")
unittest
{
    Mocker mocker;

    auto mock = mocker.mock!(Object);
    mock.expect.toHash.passThrough().repeatAny;
    mock.expect.opEquals.passThrough().repeatAny;

    auto obj = mock.get;

    int[Object] i;
    i[obj] = 5;
    int j = i[obj];
}

@("mock interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!IFace;

    obj.expect.foo("hallo");

    obj.get.foo("hallo");

    mocker.verify;
}

@("cast mock to interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!Smthng;

    obj.expect.foo("hallo");

    obj.get.foo("hallo");

    mocker.verify;
}

@("cast mock to interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!Smthng;

    obj.expect.foo("hallo");

    obj.foo("hallo");

    mocker.verify;
}

@("return user-defined type")
unittest
{
    Mocker mocker;

    auto objBuilder = mocker.mock!IRM;
    auto obj = objBuilder.get;

    auto imBuilder = mocker.mock!IM;
    auto im = imBuilder.get;

    objBuilder.expect.get().returns(im);
    objBuilder.expect.set(im);

    obj.get.should.be(im);
    obj.set(im);
    mocker.verify;
}

@("return user-defined type")
unittest
{
    Mocker mocker;
    mocker.mock!HasMember;
}

@("overloaded method")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!Overloads;
    obj.expect.foo();
    obj.expect.foo(1);

    obj.foo(1);
    obj.foo;

    mocker.verify;
}

@("returning different values on the same expectation")
unittest
{
    Mocker mocker;
    auto dependency = mocker.mock!Dependency;

    //mocker.ordered;
    dependency.expect.foo.returns(1);
    dependency.expect.foo.returns(2);

    dependency.foo.should.equal(1);
    dependency.foo.should.equal(2);

    mocker.verify;
}

@("customArgsComparator")
unittest
{
    import std.math : abs;

    enum float argument = 1.0f;

    auto mocker = configure!(Comparator!((float a, float b) => abs(a - b) < 0.1f));
    auto dependency = mocker.mock!TakesFloat;
    dependency.expect.foo(argument).repeat(2);

    // custom comparison example - treat similar floats as equals
    dependency.foo(1.01);
    dependency.foo(1.02);
}
