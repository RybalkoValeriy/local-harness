import { application } from "./application"
import ChatController from "./chat_controller"
application.register("chat", ChatController)
import FolderPickerController from "./folder_picker_controller"
application.register("folder-picker", FolderPickerController)
import ThemeController from "./theme_controller"
application.register("theme", ThemeController)
import FileTreeController from "./file_tree_controller"
application.register("file-tree", FileTreeController)
