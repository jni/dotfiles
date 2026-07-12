function nuke
    mu deactivate
    mu env remove --name all -y

    switch (uname)
        case Linux
            set yml_file ~/projects/dotfiles/conda/environments/all-linux.yml
        case Darwin
            set yml_file ~/projects/dotfiles/conda/environments/all-macos.yml
        case '*'
            set yml_file ~/projects/dotfiles/conda/environments/all.yml
    end

    mu env create -y -f $yml_file
    mu activate all

    for pkg in [napari skan affinder zarpaint]
        uv pip uninstall $pkg
        uv pip install --no-deps -e $HOME/projects/$pkg
    end
end
