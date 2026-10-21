# ----------------------------------------------------------------------------
# QGroundControl Windows Platform Configuration
# ----------------------------------------------------------------------------

if(NOT WIN32)
    message(FATAL_ERROR "QGC: Invalid Platform: Windows.cmake included but platform is not Windows")
endif()

# ----------------------------------------------------------------------------
# Windows-Specific Definitions
# ----------------------------------------------------------------------------
target_compile_definitions(${CMAKE_PROJECT_NAME}
    PRIVATE
        _USE_MATH_DEFINES    # Enable M_PI and other math constants
        NOMINMAX             # Prevent min/max macro conflicts
        WIN32_LEAN_AND_MEAN  # Reduce Windows.h bloat
)

# ----------------------------------------------------------------------------
# Windows Executable Configuration
# ----------------------------------------------------------------------------
set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES WIN32_EXECUTABLE TRUE)

if(COMMAND _qt_internal_generate_win32_rc_file)
    set_target_properties(${CMAKE_PROJECT_NAME}
        PROPERTIES
            QT_TARGET_COMPANY_NAME "${QGC_ORG_NAME}"
            QT_TARGET_DESCRIPTION "${CMAKE_PROJECT_DESCRIPTION}"
            QT_TARGET_VERSION "${CMAKE_PROJECT_VERSION}"
            QT_TARGET_COPYRIGHT "${QGC_APP_COPYRIGHT}"
            QT_TARGET_PRODUCT_NAME "${CMAKE_PROJECT_NAME}"
            # QT_TARGET_COMMENTS: ${QGC_QT_TARGET_COMMENTS}
            # QT_TARGET_ORIGINAL_FILENAME: ${QGC_QT_TARGET_ORIGINAL_FILENAME}
            # QT_TARGET_TRADEMARKS: ${QGC_QT_TARGET_TRADEMARKS}
            # QT_TARGET_INTERNALNAME: ${QGC_QT_TARGET_INTERNALNAME}
            QT_TARGET_RC_ICONS "${QGC_WINDOWS_ICON_PATH}"
    )
    _qt_internal_generate_win32_rc_file(${CMAKE_PROJECT_NAME})
elseif(EXISTS "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
    target_sources(${CMAKE_PROJECT_NAME} PRIVATE "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
    set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES QT_TARGET_WINDOWS_RC_FILE "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
elseif(EXISTS "${CMAKE_SOURCE_DIR}/deploy/windows/QGroundControl.rc.in")
    configure_file(
        "${CMAKE_SOURCE_DIR}/deploy/windows/QGroundControl.rc.in"
        "${CMAKE_BINARY_DIR}/QGroundControl.rc"
        @ONLY
    )
    target_sources(${CMAKE_PROJECT_NAME} PRIVATE "${CMAKE_BINARY_DIR}/QGroundControl.rc")
else()
    message(WARNING "QGC: No Windows resource file found")
endif()

if(MSVC)
    # qt_add_win_app_sdk(${CMAKE_PROJECT_NAME} PRIVATE)
endif()

# Qt Creator runs from the build tree, without executing the install rules.
# Deploy plugins and QML alongside the DLLs so that run does not need SDK paths.
if(TARGET Qt6::windeployqt)
    set(_qgc_speech_deploy_args)
    if(DISABLE_SPEECH)
        list(APPEND _qgc_speech_deploy_args --no-texttospeech --skip-plugin-types texttospeech)
    endif()
    add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
        COMMAND $<TARGET_FILE:Qt6::windeployqt>
            $<IF:$<CONFIG:Debug>,--debug,--release>
            ${_qgc_speech_deploy_args}
            --no-compiler-runtime
            --qmldir "${CMAKE_SOURCE_DIR}/src"
            --qmlimport "${QT_QML_OUTPUT_DIRECTORY}"
            "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
        COMMENT "Deploying Qt Windows runtime and QML imports to the build directory"
        VERBATIM
    )
    if(EXISTS "${CMAKE_SOURCE_DIR}/custom/res")
        add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
            COMMAND $<TARGET_FILE:Qt6::windeployqt>
                $<IF:$<CONFIG:Debug>,--debug,--release>
                ${_qgc_speech_deploy_args}
                --no-compiler-runtime
                --qmldir "${CMAKE_SOURCE_DIR}/custom/res"
                --qmlimport "${QT_QML_OUTPUT_DIRECTORY}"
                "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
            COMMENT "Deploying custom QML runtime imports"
            VERBATIM
        )
    endif()
endif()

message(STATUS "QGC: Windows platform configuration applied")
