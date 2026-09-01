.PHONY: project test models

project:
	xcodegen generate

test:
	python3 Tests/test_engine_ref.py

models:
	./Scripts/download-models.sh
