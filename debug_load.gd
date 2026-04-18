extends SceneTree

func _init():
    print("--- DEBUG START ---")
    var path = "res://assets/models/weapons/weaponsassetspackbyStyloo/ASSETS.fbx_bayonet.fbx"
    var res = ResourceLoader.exists(path)
    print("Resource exists?: ", res)
    var loaded = load(path)
    print("Loaded resource: ", loaded)
    if loaded:
        print("Type: ", loaded.get_class())
        var inst = loaded.instantiate()
        print("Instantiated: ", inst)
        print("Instantiated scale: ", inst.scale)
        for child in inst.get_children():
            print("  Child: ", child.name, " scale: ", child.scale)
    print("--- DEBUG END ---")
    quit()
