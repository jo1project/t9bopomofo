.PHONY: project test dict

project:
	xcodegen generate

test:
	python3 Tests/test_engine_ref.py

dict:
	python3 Scripts/build-chewing-dict.py
