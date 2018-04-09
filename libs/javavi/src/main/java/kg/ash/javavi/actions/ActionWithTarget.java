package kg.ash.javavi.actions;

import kg.ash.javavi.Javavi;
import kg.ash.javavi.TargetParser;

public abstract class ActionWithTarget implements Action {

    protected TargetParser targetParser;
    protected String sources;

    public ActionWithTarget() {
        String javaViSources = Javavi.system.get("sources");
        sources = javaViSources != null ? javaViSources.replace('\\', '/') : "";
        targetParser = new TargetParser(sources);
    }

    protected String parseTarget(String[] args) {
        if (args.length > 0) {
            return targetParser.parse(args[args.length - 1]);
        }
        return "";
    }
}
