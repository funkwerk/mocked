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

## Introduction

### Why are mocks useful?

Assuming that you've decided to use unit tests (if you didn't you're wrong), you
need a strategy for keeping scope of your unit tests small, so they only test
one method or one small group of methods at a time. Otherwise, you're using a
unit test system for integration tests. Which is fine, but can be uneffective -
the number of integration tests needed for full coverage of 3 interacting
objects is much larger than number of equivalent unit tests needed and unit
tests were invented exactly to solve that problem.

The simplest strategy is to keep your classes small and not have them talk to
each other. This might work for a standard library such as Phobos or Unstd, but
it does not scale to large applications.

Classical example of the problem is an object which depends on a DB connection.
Testing methods of such object is difficult because you have to provide some
database for this object, otherwise your code won't compile or throw a
NullPointerException. You could provide a separate database for testing, but
that brings other problems: it takes long to connect to a DB and it's still hard
to simulate certain conditions, like timeouts.

**Mocks** are an alternative sollution to the problem - you create a mock object
which will pretend that it provides a DB connection (it implements the same
"interface"). You can make the mock object return predefined records, timeout on
request (to test error handling), etc. You can make it check if methods are
really called i.e you expect function retrieving data to call connect(), because
it not doing so is an error. Now you run tests against object with fake (mocked)
DB connection. This way, only the code you want to test is tested, nothing more.

### Why is mockeD useful?

A mock objects framework allows you to quickly create mock objects, set up
expectations for them, and check to see whether these expectations have been
fulfilled. This saves you tedious work of creating those objects manually.

## Expectation setup

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
import mocked;
import std.exception : assertThrown;

Mocker mocker;
auto mock = mocker.mock!Object;
mock.expect.toString.throws(new Exception(""));

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
