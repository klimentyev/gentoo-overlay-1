cmake_minimum_required(VERSION 3.8)

project(TelegramDesktop)

set(CMAKE_CXX_STANDARD 17)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

include(GNUInstallDirs)

list(APPEND CMAKE_MODULE_PATH
	${CMAKE_SOURCE_DIR}/gyp
	${CMAKE_SOURCE_DIR}/cmake
)

option(BUILD_TESTS "Build all available test suites" OFF)
option(ENABLE_CRASH_REPORTS "Enable crash reports" ON)
option(ENABLE_GTK_INTEGRATION "Enable GTK integration" ON)

find_package(LibLZMA REQUIRED)
find_package(OpenAL REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Threads REQUIRED)
find_package(X11 REQUIRED)
find_package(ZLIB REQUIRED)

find_package(Qt5 REQUIRED COMPONENTS Core DBus Gui Widgets Network)
get_target_property(QTCORE_INCLUDE_DIRS Qt5::Core INTERFACE_INCLUDE_DIRECTORIES)
list(GET QTCORE_INCLUDE_DIRS 0 QT_INCLUDE_DIR)

foreach(__qt_module IN ITEMS QtCore QtGui)
	list(APPEND QT_PRIVATE_INCLUDE_DIRS
		${QT_INCLUDE_DIR}/${__qt_module}/${Qt5_VERSION}
		${QT_INCLUDE_DIR}/${__qt_module}/${Qt5_VERSION}/${__qt_module}
	)
endforeach()
message(STATUS "Using Qt private include directories: ${QT_PRIVATE_INCLUDE_DIRS}")

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED libavcodec libavformat libavutil libswresample libswscale)
pkg_check_modules(LIBDRM REQUIRED libdrm)
pkg_check_modules(LIBVA REQUIRED libva libva-drm libva-x11)
pkg_check_modules(MINIZIP REQUIRED minizip)

set(THIRD_PARTY_DIR ${CMAKE_SOURCE_DIR}/ThirdParty)
list(APPEND THIRD_PARTY_INCLUDE_DIRS
	${THIRD_PARTY_DIR}/crl/src
	${THIRD_PARTY_DIR}/GSL/include
	${THIRD_PARTY_DIR}/emoji_suggestions
	${THIRD_PARTY_DIR}/libtgvoip
	${THIRD_PARTY_DIR}/variant/include
)

add_subdirectory(${THIRD_PARTY_DIR}/crl)
add_subdirectory(${THIRD_PARTY_DIR}/libtgvoip)

set(TELEGRAM_SOURCES_DIR ${CMAKE_SOURCE_DIR}/SourceFiles)
set(TELEGRAM_RESOURCES_DIR ${CMAKE_SOURCE_DIR}/Resources)

include_directories(${TELEGRAM_SOURCES_DIR})

set(GENERATED_DIR ${CMAKE_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${GENERATED_DIR})

include(TelegramCodegen)
set_property(SOURCE ${TELEGRAM_GENERATED_SOURCES} PROPERTY SKIP_AUTOMOC ON)

set(QRC_FILES
	Resources/qrc/telegram.qrc
	Resources/qrc/telegram_emoji.qrc
	Resources/qrc/telegram_emoji_large.qrc
	# This only disables system plugin search path
	# We do not want this behavior for system build
	# Resources/qrc/telegram_linux.qrc
)

file(GLOB FLAT_SOURCE_FILES
	SourceFiles/*.cpp
	SourceFiles/base/*.cpp
	SourceFiles/calls/*.cpp
	SourceFiles/chat_helpers/*.cpp
	SourceFiles/core/*.cpp
	SourceFiles/data/*.cpp
	SourceFiles/dialogs/*.cpp
	SourceFiles/history/*.cpp
	SourceFiles/inline_bots/*.cpp
	SourceFiles/intro/*.cpp
	SourceFiles/lang/*.cpp
	SourceFiles/mtproto/*.cpp
	SourceFiles/overview/*.cpp
	SourceFiles/passport/*.cpp
	SourceFiles/platform/linux/*.cpp
	SourceFiles/profile/*.cpp
	SourceFiles/settings/*.cpp
	SourceFiles/storage/*.cpp
	${THIRD_PARTY_DIR}/emoji_suggestions/*.cpp
)
file(GLOB FLAT_EXTRA_FILES
	SourceFiles/qt_static_plugins.cpp
	SourceFiles/base/*_tests.cpp
	SourceFiles/base/tests_main.cpp
	SourceFiles/passport/passport_edit_identity_box.cpp
	SourceFiles/passport/passport_form_row.cpp
)
list(REMOVE_ITEM FLAT_SOURCE_FILES ${FLAT_EXTRA_FILES})

file(GLOB_RECURSE SUBDIRS_SOURCE_FILES
	SourceFiles/boxes/*.cpp
	SourceFiles/export/*.cpp
	SourceFiles/history/*.cpp
	SourceFiles/info/*.cpp
	SourceFiles/media/*.cpp
	SourceFiles/ui/*.cpp
	SourceFiles/window/*.cpp
)

add_executable(Telegram WIN32 ${QRC_FILES} ${FLAT_SOURCE_FILES} ${SUBDIRS_SOURCE_FILES})

set(TELEGRAM_COMPILE_DEFINITIONS
	Q_OS_LINUX64
	TDESKTOP_DISABLE_AUTOUPDATE
	TDESKTOP_DISABLE_DESKTOP_FILE_GENERATION
	TDESKTOP_DISABLE_UNITY_INTEGRATION
	__STDC_FORMAT_MACROS
)

set(TELEGRAM_INCLUDE_DIRS
	${FFMPEG_INCLUDE_DIRS}
	${GENERATED_DIR}
	${LIBDRM_INCLUDE_DIRS}
	${LIBLZMA_INCLUDE_DIRS}
	${LIBVA_INCLUDE_DIRS}
	${MINIZIP_INCLUDE_DIRS}
	${OPENAL_INCLUDE_DIR}
	${QT_PRIVATE_INCLUDE_DIRS}
	${THIRD_PARTY_INCLUDE_DIRS}
	${ZLIB_INCLUDE_DIR}
)

set(TELEGRAM_LINK_LIBRARIES
	crl
	tgvoip
	OpenSSL::Crypto
	OpenSSL::SSL
	Qt5::DBus
	Qt5::Network
	Qt5::Widgets
	Threads::Threads
	${FFMPEG_LIBRARIES}
	${LIBDRM_LIBRARIES}
	${LIBLZMA_LIBRARIES}
	${LIBVA_LIBRARIES}
	${MINIZIP_LIBRARIES}
	${OPENAL_LIBRARY}
	${X11_X11_LIB}
	${ZLIB_LIBRARY_RELEASE}
)

if(ENABLE_CRASH_REPORTS)
	find_package(Breakpad REQUIRED)
	list(APPEND TELEGRAM_LINK_LIBRARIES
		breakpad_client
	)
else()
	list(APPEND TELEGRAM_COMPILE_DEFINITIONS
		TDESKTOP_DISABLE_CRASH_REPORTS
	)
endif()

if(ENABLE_GTK_INTEGRATION)
	pkg_check_modules(APPINDICATOR REQUIRED appindicator3-0.1)
	pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
	list(APPEND TELEGRAM_INCLUDE_DIRS
		${APPINDICATOR_INCLUDE_DIRS}
		${GTK3_INCLUDE_DIRS}
	)
	list(APPEND TELEGRAM_LINK_LIBRARIES
		${APPINDICATOR_LIBRARIES}
		${GTK3_LIBRARIES}
	)
else()
	list(APPEND TELEGRAM_COMPILE_DEFINITIONS
		TDESKTOP_DISABLE_GTK_INTEGRATION
	)
endif()

target_sources(Telegram PRIVATE ${TELEGRAM_GENERATED_SOURCES})
add_dependencies(Telegram telegram_codegen)

include(PrecompiledHeader)
add_precompiled_header(Telegram SourceFiles/stdafx.h)

target_compile_definitions(Telegram PUBLIC ${TELEGRAM_COMPILE_DEFINITIONS})
target_include_directories(Telegram PUBLIC ${TELEGRAM_INCLUDE_DIRS})
target_link_libraries(Telegram ${TELEGRAM_LINK_LIBRARIES})

set_target_properties(Telegram PROPERTIES AUTOMOC_MOC_OPTIONS -bTelegram_pch/stdafx.h)

if(BUILD_TESTS)
	include(TelegramTests)
endif()

install(TARGETS Telegram RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(PROGRAMS ${CMAKE_SOURCE_DIR}/../lib/xdg/telegram-desktop.desktop DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
