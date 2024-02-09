# Build.nvim extension

Problem: I work on compiled project, say C and I want the output to be nicely printed with the colors of the million warnings and errors during compilation. Usually I would map make to <leader>m get a wall of text that I will skip over and then do the same thing in the terminal that I have next to my editor. Because it's unreadable + the output gets basically discarded after running the command. This is counterproductive, either way I have to have a terminal open.
Solution: Better make output reporting. Either select that the output of the command would go to the easily toggable floating window or better yet, spawn a seperate terminal emulator window (not the neovim integrated one) tied to the neovim instance that receives all the compilation requests and runs it remotely! Why is this a better way than having it inside neovim? Well now you can say, put that terminal to the other monitor and run it there!

For now nothing really as all the options are fixed but if I get more time I might work on it a bit more
