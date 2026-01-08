# Test Runner Scene
# Run all tests with: godot --headless --script tests/run_tests.gd
extends SceneTree

func _init():
	print("\n========================================")
	print("  WolfGodot Test Suite")
	print("========================================\n")
	
	# Run extraction tests
	var extraction_results = TestExtraction.run_all()
	
	print("\n----------------------------------------")
	print("SUMMARY")
	print("----------------------------------------")
	print("Total Passed: %d" % extraction_results.passed)
	print("Total Failed: %d" % extraction_results.failed)
	
	if extraction_results.failed == 0:
		print("\nALL TESTS PASSED!")
	else:
		print("\nSOME TESTS FAILED")
	
	print("========================================\n")
	
	# Exit with appropriate code
	quit(0 if extraction_results.failed == 0 else 1)
