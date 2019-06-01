INCLUDE(FindPkgConfig)
PKG_CHECK_MODULES(PC_ZLUUDGBEE zluudgbee)

FIND_PATH(
    ZLUUDGBEE_INCLUDE_DIRS
    NAMES zluudgbee/api.h
    HINTS $ENV{ZLUUDGBEE_DIR}/include
        ${PC_ZLUUDGBEE_INCLUDEDIR}
    PATHS ${CMAKE_INSTALL_PREFIX}/include
          /usr/local/include
          /usr/include
)

FIND_LIBRARY(
    ZLUUDGBEE_LIBRARIES
    NAMES gnuradio-zluudgbee
    HINTS $ENV{ZLUUDGBEE_DIR}/lib
        ${PC_ZLUUDGBEE_LIBDIR}
    PATHS ${CMAKE_INSTALL_PREFIX}/lib
          ${CMAKE_INSTALL_PREFIX}/lib64
          /usr/local/lib
          /usr/local/lib64
          /usr/lib
          /usr/lib64
)

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(ZLUUDGBEE DEFAULT_MSG ZLUUDGBEE_LIBRARIES ZLUUDGBEE_INCLUDE_DIRS)
MARK_AS_ADVANCED(ZLUUDGBEE_LIBRARIES ZLUUDGBEE_INCLUDE_DIRS)

