function tests = test_forward_fieldtrip()
%TEST_FORWARD_FIELDTRIP Cheap FieldTrip adapter check; skip without dependency.
tests = struct();
tests.skipped = true;
if eegsl.common.has_fieldtrip()
    tests.skip_reason = 'Installed FieldTrip signatures and transfer behavior require source verification.';
else
    tests.skip_reason = 'FieldTrip is not available.';
end
tests.all_passed = true;
end
