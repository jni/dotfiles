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
    uv pip uninstall -y napari
    uv pip install -U -e "$HOME/projects/napari[dev,testing]"
    uv pip install -U -e "$HOME/projects/skan"
    uv pip install -U -e "$HOME/projects/affinder"
    uv pip install -U -e "$HOME/projects/zarpaint"
end
