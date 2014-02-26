WORKSPACE=STBlockingQueue.xcworkspace
SCHEME=STBlockingQueue

clean:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} clean

build:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} build -sdk iphonesimulator

test:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} run-tests -test-sdk iphonesimulator -parallelize

