export PATH=/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin:"${PATH}"
swift build
cd .build/debug
./MusicMatchServer
