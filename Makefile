WORKSPACE=STBlockingQueue.xcworkspace
SCHEME=STBlockingQueue

test:
	xcodebuild test -workspace ${WORKSPACE} -scheme ${SCHEME} -destination 'name=iPhone Retina (3.5-inch),OS=7.0'

