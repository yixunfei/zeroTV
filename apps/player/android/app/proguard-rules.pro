# zeroTV Android R8 rules.
#
# Flutter plugins ship their own consumer rules (merged automatically),
# including the JNI keep rules for media_kit and the workmanager
# callback receiver, so no project-specific keeps are required.
# Add them below if a plugin misbehaves in release builds.
