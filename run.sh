clear
clean () {
	swift build --clean
	echo "Cleaning..."
}
if [ $1 = -clean ]
then
	clean
fi

swift build -Xswiftc -suppress-warnings
./.build/debug/MusicMatchServer
