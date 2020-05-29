# MockeD

![CI](https://github.com/funkwerk/mocked/workflows/CI/badge.svg)
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

## Why are mocks useful?

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

More examples about use of mocks can be found at: http://www.youtube.com/watch?v=V98Z11V7kEY

## Why is mockeD useful?

A mock objects framework allows you to quickly create mock objects, set up
expectations for them, and check to see whether these expectations have been
fulfilled. This saves you tedious work of creating those objects manually.
