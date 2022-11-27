# Note that headers are optional, and do not affect add_library, but they will not
# show up in IDEs unless they are listed in add_library.

set(HEADER_LIST "${libgurucv_SOURCE_DIR}/include/libgurucv/preprocess.hpp")

# Make an automatic library - will be static or dynamic based on user setting
add_library(libgurucv preprocess.cpp ${HEADER_LIST})

# We need this directory, and users of our library will need it too
target_include_directories(libgurucv PUBLIC ../include)

# IDEs should put the headers in a nice place
source_group(
  TREE "${PROJECT_SOURCE_DIR}/include"
  PREFIX "Header Files"
  FILES ${HEADER_LIST})

