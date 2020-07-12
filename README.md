# MockeD

[![CI](https://github.com/funkwerk/mocked/workflows/CI/badge.svg)](https://github.com/funkwerk/mocked/actions?query=workflow%3ACI)
[![License](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://raw.githubusercontent.com/funkwerk/mocked/master/LICENSE)
[![codecov](https://codecov.io/gh/funkwerk/mocked/branch/master/graph/badge.svg)](https://codecov.io/gh/funkwerk/mocked)
[![Dub version](https://img.shields.io/dub/v/mocked.svg)](https://code.dlang.org/packages/mocked)
[![Dub downloads](https://img.shields.io/dub/dt/mocked.svg)](https://code.dlang.org/packages/mocked)

A mocking framework for the D programming language.

## Getting started

```d
import mocked;

class Dependency
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
```

## Expectation setup

This library defines `Mocker` data type used to create mocks.

`Mocker.mock!T` returns a mock builder, `Mocked!T`, which is used to configure
mock's behavior. `Mocked!T.expect` has all virtual methods defined in `T`, with
the same type signatures. These methods can be used to set the arguments the
methods are expected to be called with. If you don't pass any arguments, then
the call to the function will still be expected, but the arguments, it will be
called with, will be ignored.

```d
import mocked

class Dependency
{
    void say(string)
    {
    }
}
Mocker mocker;
auto mock = mocker.mock!Dependency;
mock.expect.say("Naturam expelles furca, tamen usque recurret. (Horace)");
// or mock.expect.say(); to ignore the arguments

mock.get.say("Naturam expelles furca, tamen usque recurret. (Horace)");
```

`mock.get` returns the mocked object itself (child class or an interface
implementation). If `mock.get.say` was called with a different string or
wasn't called at all, an error would be thrown.

If the mocked function has several overloads, and you'd like to ignore the
arguments, you have to specify explicitly, which overload is expected to be
called. You can do it by providing the types of the arguments. In the
above example you would write: `mock.expect.say!string()`, since the function
`Dependency.say` has a single `string` parameter.

You can configure consecutive calls to `Dependency.say()` by calling
`.expect.say(...)` multiple times.

### Stubs

MockeD provides an API for creating stubs. The API is very similar to the mock
API. Just replace `Mocker.mock!T` with `Mocker.stub!T` and
`mock.expect.method(arguments)` with `mock.stub.method(arguments)`.

The arguments won't be used to verify the expectations (there are no
expectations), but to match a configured method. In the following example we
configure the stub to return the respective authors (values) for different
phrases (arguments).

```d
import mocked

enum string vergil = "tu ne cede malis, sed contra audentior ito.";
enum string plotinus = "neque est alter hijus universi locus, quam anima";
class Dependency
{
    string authorOf(string)
    {
        return null;
    }
}
Mocker mocker;
auto stub = mocker.stub!Dependency;
stub.stub.authorOf(vergil).returns("Vergil");
stub.stub.authorOf(plotinus).returns("Plotinus");

assert(stub.get.authorOf(vergil) == "Vergil");
assert(stub.get.authorOf(plotinus) == "Plotinus");
```

The stub builder for `T` is called `Stubbed!T`.

### passThrough

Instead of returning or throwing a given value, pass the call through to
the mocked type object.

```d
import mocked;

class Dependency
{
    bool isTrue()
    {
        return true;
    }
}
Mocker mocker;
auto mock = mocker.mock!Dependency;
mock.expect.isTrue.passThrough;

assert(mock.get.isTrue);
```

### returns

Set the value to return when method matching this expectation is called on a
mock object.

```d
import mocked;

Mocker mocker;
auto mock = mocker.mock!Object;
mock.expect.toString.returns("in abstracto");

assert(mock.get.toString == "in abstracto");
```

### throws

When the method which matches this expectation is called, throw the given
exception.

```d
import std.exception : assertThrown;

Mocker mocker;
auto mock = mocker.mock!Object;
mock.expect.toString.throws!Exception("");

assertThrown!Exception(mock.get.toString);
```

### action

When the method which matches this expectation is called execute the given
delegate. The delegate's signature must match the signature of the called
method.

```d
static bool flag = false;

class Dependency
{
    void setFlag(bool flag)
    {
    }
}
Mocker mocker;
auto mock = mocker.mock!Dependency;
mock.expect.setFlag.action((value) { flag = value; });

mock.get.setFlag(true);

assert(flag);
```

### repeat/repeatAny

This expectation will match exactly `n` times or any number of calls,
respectively.

```d
enum string expected = "Three times you must say it, then.";
Mocker mocker;

auto builder = mocker.mock!Object;
builder.expect.toString.returns(expected).repeat(3);
// Or: builder.expect.toString.returns(expected).repeatAny;

auto mock = builder.get;

assert(mock.toString() == expected);
assert(mock.toString() == expected);
assert(mock.toString() == expected);
```

## Configuration

### Custom argument comparator

You can provide a function, which will be used to compare two objects of a
specific type. Use `configure` instead of the `Mocker` to create a custom mocker
instance. `configure` takes a tuple of `Comparator`s, so you can specify as many
comparators as you like, but they aren't allowed to conflict, so the types in
question should be distinct types.

Every `Comparator` has a single template parameter which is a function actually
used for the comparison. This function should have exactly two arguments of the
same type and return a boolean value.

```d
import mocked;
import std.math : fabs;

class Dependency
{
    public void call(float)
    {
    }
}

// This function is used to compare two floating point numbers that don't
// match exactly.
alias approxComparator = (float a, float b) {
    return fabs(a - b) <= 0.1;
};
auto mocker = configure!(Comparator!approxComparator);
auto builder = mocker.mock!Dependency;

builder.expect.call(1.01);

auto mock = builder.getMock;

mock.call(1.02);

mocker.verify;
```
