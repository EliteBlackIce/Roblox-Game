use mlua::{Lua, Result, Value};
use std::fs;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let lua = Lua::new();
    // readfile + compile helpers for the Lua-side mock require system.
    let readfile = lua.create_function(|_, path: String| {
        Ok(fs::read_to_string(&path).ok())
    })?;
    lua.globals().set("__readfile", readfile)?;
    let loadsrc = lua.create_function(|lua, (src, name): (String, String)| {
        match lua.load(&src).set_name(name).into_function() {
            Ok(f) => Ok((Value::Function(f), Value::Nil)),
            Err(e) => Ok((Value::Nil, Value::String(lua.create_string(&e.to_string())?))),
        }
    })?;
    lua.globals().set("__loadsrc", loadsrc)?;
    let argv = lua.create_table()?;
    for (i, a) in args.iter().enumerate() {
        argv.set(i, a.clone())?;
    }
    lua.globals().set("__ARGS", argv)?;
    let src = fs::read_to_string(&args[1]).expect("read script");
    let res = lua.load(&src).set_name(args[1].clone()).exec();
    if let Err(e) = res {
        eprintln!("ERROR: {}", e);
        std::process::exit(1);
    }
    Ok(())
}
