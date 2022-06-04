import unit_threaded;

import mocked.tests.alien;
import mocked.tests.expectations;
import mocked.tests.mocking;
import mocked.tests.option;
import mocked.tests.readme;
import mocked.tests.stub;

mixin runTestsMain!(
    mocked.tests.alien,
    mocked.tests.expectations,
    mocked.tests.mocking,
    mocked.tests.option,
    mocked.tests.readme,
    mocked.tests.stub,
);
