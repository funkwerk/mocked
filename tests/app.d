import unit_threaded;

import mocked.tests.expectations;
import mocked.tests.mocking;
import mocked.tests.readme;

mixin runTestsMain!(
    mocked.tests.alien,
    mocked.tests.expectations,
    mocked.tests.mocking,
    mocked.tests.option,
    mocked.tests.readme,
    mocked.tests.stub,
);
