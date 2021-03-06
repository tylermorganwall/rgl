
# This displays an HTML5 input widget to show a subset of objects.  It assigns a random id
# and returns that invisibly.

subsetSlider <- function(subsets, labels = names(subsets),
                         fullset = Reduce(union, subsets), 
                         subscenes = currentSubscene3d(), prefixes = "", 
                         accumulate = FALSE, ...) {
  propertySlider(subsetSetter(subsets, fullset = fullset,
                              subscenes = subscenes, prefixes = prefixes,
                              accumulate = accumulate),
                 labels = labels, ...)
}

subsetSetter <- function(subsets, subscenes = currentSubscene3d(), prefixes = "",
			 fullset = Reduce(union, subsets),
			 accumulate = FALSE) {
  nsubs <- max(length(subscenes), length(prefixes))
  subscenes <- rep(subscenes, length.out = nsubs)
  prefixes <- rep(prefixes, length.out = nsubs)
  result <- subst(
'function(value) {
  var i, ids = [%vals%],
      fullset = [%fullset%], entries,
      f = function(x) { return fullset.indexOf(x) < 0; };
  value = Math.round(value);',
    vals = paste(paste0("[", sapply(subsets,
        				function(i) paste(i, collapse=",")),
        				"]"), collapse=","),
    fullset = paste(fullset, collapse=","))
  for (i in seq_len(nsubs))
    result <- c(result, subst(
'  if (typeof %prefix%rgl.getObj === "undefined") return;
  entries = %prefix%rgl.getObj(%subscene%).objects;
  entries = entries.filter(f);', prefix = prefixes[i], subscene = subscenes[i]),
      if (accumulate)
'  for (i=0; i<=value; i++)
    entries = entries.concat(ids[i]);'
      else
'  entries = entries.concat(ids[value]);',
      subst('
  %prefix%rgl.setSubsceneEntries(entries, %subscene%);',
      prefix = prefixes[i], subscene = subscenes[i]))
  result <- c(result, '}')

  structure(paste(result, collapse = "\n"),
    param = seq_along(subsets) - 1,
    prefixes = prefixes, class = "propertySetter")
}

toggleButton <- function(subset, subscenes = currentSubscene3d(), prefixes = "",
			 label = deparse(substitute(subset)),
			 id = paste0(basename(tempfile("input"))), name = id) {
  nsubs <- max(length(subscenes), length(prefixes))
  subscenes <- rep(subscenes, length.out = nsubs)
  prefixes <- rep(prefixes, length.out = nsubs)
  result <- subst(
'<button type="button" id="%id%" name="%name%" onclick = "(function(){
  var subset = [%subset%], i;',
    name, id, subset = paste(subset, collapse=","))
  for (i in seq_len(nsubs))
    result <- c(result, subst(
'  if (%prefix%rgl.inSubscene(subset[0], %subscene%)) {
    for (i=0; i<subset.length; i++)
      %prefix%rgl.delFromSubscene(subset[i], %subscene%);
  } else {
    for (i=0; i<subset.length; i++)
      %prefix%rgl.addToSubscene(subset[i], %subscene%);
  }', prefix = prefixes[i], subscene = subscenes[i]))
  prefixes <- unique(prefixes)
  for (i in seq_along(prefixes))
    result <- c(result, subst(
'  %prefix%rgl.drawScene();', prefix = prefixes[i]))
  result <- c(result, subst(
'})()">%label%</button>', label))
  cat(result, sep = "\n")
  invisible(id)
}

clipplaneSlider <- function(a=NULL, b=NULL, c=NULL, d=NULL,
			    plane = 1, clipplaneids, prefixes = "",
			    labels = signif(values[,1],3),
			      ...) {
  values <- cbind(a = a, b = b, c = c, d = d)
  col <- which(colnames(values) == letters[1:4]) - 1
  propertySlider(values = values, entries = 4*(plane-1) + col,
  	         properties = "vClipplane", objids = clipplaneids,
  	         prefixes = prefixes, labels = labels, ...)
}

propertySlider <- function(setter = propertySetter,
                           minS = NULL, maxS = NULL, step = 1, init = NULL,
                           labels,
                           id = basename(tempfile("input")), name = id,
			   outputid = paste0(id, "text"),
			   index = NULL,
                           ...)  {
  displayVals <- function(x) {
    base <- signif(mean(x), 2)
    base + signif(x - base, 2)
  }
  if (!is.list(setter)) setters <- list(setter)
  else setters <- setter
  param <- numeric()
  prefixes <- character()
  for (i in seq_along(setters)) {
    setter <- setters[[i]]
    if (is.function(setter))
      setters[i] <- setter <- setter(...)
    if (!inherits(setter, "propertySetter"))
    stop("'setter' must be a propertySetter object")

    param <- c(param, attr(setter, "param"))
    prefixes <- c(prefixes, attr(setter, "prefixes"))
  }
  prefix <- prefixes[1]

  if (is.null(minS)) minS <- min(param)
  if (is.null(maxS)) maxS <- max(param)
  if (is.null(init)) init <- minS

  sliderVals <- seq(minS, maxS, by = step)
  if (missing(labels)) labels <- displayVals(sliderVals)
  if (is.null(outputid) || is.null(labels)) outputfield <- setoutput <- ""
  else {
    outputfield <- subst('<output id="%outputid%" for="%id%">%label%</output>',
  			  outputid, id, label = labels[round(init-minS)/step + 1])
    setoutput <- subst('
  label = document.getElementById(\'%outputid%\');
  if (label !== null) label.value = labels[lvalue];', outputid)
  }
  # We don't want to respond to a change in the middle of a
  # previous response, but we don't want to lose it either.
  result <- subst(
'<script>%prefix%rgl.%id% = function(value){
  if (typeof %prefix%rgl.drawScene === "undefined")
    return;
  var busy = (typeof %prefix%rgl.%id%.busy !== "undefined"),
      lvalue, labels;
  try {
    %prefix%rgl.%id%.busy = value;
    if (busy) return;
    do {', prefix, id)
  for (i in seq_along(setters)) {
    setter <- setters[[i]]
    if (inherits(setter, "indexedSetter")) {
      if (is.null(index)) stop("indexed setter requires an index")
      settername <- attr(setter, "name")
    }
    result <- c(result,
      if (!inherits(setter, "indexedSetter")) subst(
'       (%setter%)(value);', setter)
      else subst(
'       %settername%(value, %index%);', settername, index=index-1))
  }
  for (p in unique(prefixes))
    result <- c(result, subst(
'       %prefix%rgl.drawScene();', prefix = p))
  result <- c(result, subst(
'       lvalue = Math.round((value - %minS%)/%step%);
       labels = [%labels%]; %setoutput%
     } while (%prefix%rgl.%id%.busy !== value);
  }
  finally {
    if (!busy)
      %prefix%rgl.%id%.busy = undefined;
  }
};
%prefix%rgl.%id%(%init%);</script>
<input type="range" min="%minS%" max="%maxS%" step="%step%" value="%init%" id="%id%" name="%name%"
oninput = "%prefix%rgl.%id%(this.valueAsNumber)">%outputfield%',
    prefix, id, setoutput, outputfield,
    minS, maxS, step, init, name,
    labels = paste0("'", labels, "'", collapse=",")))
  cat(result, sep="\n")
  invisible(id)
}

propertySetter <- function(values = NULL, entries, properties, objids, prefixes = "",
                           param = seq_len(NROW(values)), interp = TRUE,
			   digits = 7)  {
  direct <- is.null(values)
  ncol <- length(entries)
  if (direct)
    interp <- FALSE
  else {
    values <- matrix(values, NROW(values))
    stopifnot(ncol(values) == ncol,
              all(diff(param) > 0))
  }
  prefixes <- rep(prefixes, length.out = ncol)
  if (!ncol) return(structure("function(value) {}", param = param,
  			    prefixes = prefixes,
  			    class = "propertySetter"))
  properties <- rep(properties, length.out = ncol)
  objids <- rep(objids, length.out = ncol)
  prefix <- prefixes[1]
  property <- properties[1]
  objid <- objids[1]

  if (interp) values <- rbind(values[1,], values, values[nrow(values),])
  get <- if (grepl("^par3d\\.userMatrix", property)) ".getAsArray()" else ""
  load <- if (grepl("^par3d\\.userMatrix", property)) ".load(propvals)" else "= propvals"
  result <- c(
'function(value){',

    if (!direct) subst(
'   var values = [%vals%],',
     vals = paste(formatC(as.vector(t(values)), digits = digits, width = 1),
     	          collapse = ",")),

   subst(
'   propvals = %prefix%rgl.getObj(%objid%).%property%%get%;',
     prefix, property, objid, get),

   if (interp) subst(
'   var svals = [-Infinity, %svals%, Infinity],
        v1, v2;
   for (var i = 1; i < svals.length; i++)
     if (value <= svals[i]) {
       var p = (svals[i] - value)/(svals[i] - svals[i-1]);',
     svals = paste(formatC(param, digits = digits, width = 1), collapse = ","))
   else if (!direct)
'   value = Math.round(value);')

  for (j in seq_along(entries)) {
    newprefix <- prefixes[j]
    newprop <- properties[j]
    newget <- if (grepl("^par3d\\.userMatrix", newprop)) ".getAsArray()" else ""
    newload <- if (grepl("^par3d\\.userMatrix", newprop)) ".load(propvals)" else " = propvals"
    newid <- objids[j]
    multiplier <- ifelse(ncol>1, paste0(ncol, "*"), "")
    offset <-     ifelse(j>1,  paste0("+", j-1), "")
    result <- c(result,

    if (newprefix != prefix || newprop != property || newid != objid) subst(
'   %prefix%rgl.getObj(%objid%).%property%%load%;
   propvals = %newprefix%rgl.getObj(%objid%).%newprop%%newget%;',
      prefix, property, objid, load, newget, newprefix, newprop, newid),

    if (interp) subst(
'       v1 = values[%multiplier%(i-1)%offset%];
       v2 = values[%multiplier%i%offset%];
       propvals[%entry%] = p*v1 + (1-p)*v2;', entry=entries[j], multiplier, offset)
     else if (!direct) subst(
'   propvals[%entry%] = values[%multiplier%value%offset%];',
      entry = entries[j], multiplier, offset)
     else if (ncol == 1) subst(
'   propvals[%entry%] = value;',
     	entry = entries[j], jm1 = j - 1)
     else subst(
'   propvals[%entry%] = value[%jm1%];',
      entry = entries[j], jm1 = j - 1))

    prefix <- newprefix
    property <- newprop
    objid <- newid
    get <- newget
    load <- newload
  }
  result <- c(result,
    if (interp)
'       break;
     }',
    subst(
'   %prefix%rgl.getObj(%objid%).%property%%load%;',
      prefix, property, objid, load))

  needsBinding <- unique(data.frame(prefixes, objids)[properties == "values",])
  if (nrow(needsBinding))
    result <- c(result,
'   var gl;')
  for (i in seq_len(nrow(needsBinding))) {
    prefix <- needsBinding[i, 1]
    objid <- needsBinding[i, 2]
    result <- c(result, subst(
'   if (typeof %prefix%rgl.getObj(%objid%).buf !== "undefined") {
     gl = %prefix%rgl.gl;
     gl.bindBuffer(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).buf);
     gl.bufferData(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).values, gl.STATIC_DRAW);
   }', prefix, objid))
   }
   result <- c(result, '}')
  result <- structure(paste(result, collapse = "\n"),
    prefixes = prefixes,
    class = "propertySetter")
  if (!direct)
    attr(result, "param") <- param
  result
}

vertexSetter <- function(values = NULL, vertices = 1, attributes, objid, prefix = "",
			 param = seq_len(NROW(values)), interp = TRUE,
			 digits = 7)  {
  attribofs <- c(x = 'vofs', y = 'vofs', z = 'vofs',
  	    r = 'cofs', g = 'cofs', b = 'cofs', a = 'cofs',
            nx = 'nofs', ny = 'nofs', nz = 'nofs',
	    radius = 'radofs',
            ox = 'oofs', oy = 'oofs', oz = 'oofs',
  	    ts = 'tofs', tt = 'tofs')
  attribofsofs <- structure(c(0:2, 0:3, 0:2, 0, 0:2, 0:1),
  			    names = names(attribofs))
  direct <- is.null(values)
  ncol <- max(if (is.matrix(values)) ncol(values),
  	      length(vertices), length(attributes))
  if (direct)
    interp <- FALSE
  else {
    values <- matrix(values, NROW(values))
    stopifnot(ncol(values) == ncol,
  		  all(diff(param) > 0))
  }

  attributes <- match.arg(attributes, names(attribofs), several.ok = TRUE)
  stopifnot(length(objid) == 1,
	    length(prefix) == 1,
            all(attributes %in% names(attribofs)),
	    all(diff(param) > 0))
  vertices <- rep(vertices, length.out = ncol)
  attributes <- rep(attributes, length.out = ncol)

  if (!ncol) return(structure("function(value) {}", param = param,
			      prefixes = prefix,
			      class = c("vertexSetter", "propertySetter")))

  if (interp) values <- rbind(values[1,], values, values[nrow(values),])
  result <- c(
'function(value){',

    if (direct)
'  var ofs;'
    else subst(
'  var ofs, values = [%vals%],',
    vals = paste(formatC(as.vector(t(values)), digits = digits, width = 1),
	         collapse = ",")),

    subst(
'  propvals = %prefix%rgl.getObj(%objid%).values,
  stride = %prefix%rgl.getObj(%objid%).vOffsets.stride;',
	prefix, objid),

    if (interp) subst(
'  var p, v1, v2, svals = [-Infinity, %svals%, Infinity];
  for (var i = 1; i < svals.length; i++)
    if (value <= svals[i]) {
      p = (svals[i] - value)/(svals[i] - svals[i-1]);',	svals = paste(formatC(param, digits = digits, width = 1), collapse = ","))
    else if (!direct)
'  value = Math.round(value);')

  for (j in seq_along(vertices)) {
    multiplier <- ifelse(ncol>1, paste0(ncol, "*"), "")
    offset <-     ifelse(j>1,  paste0("+", j-1), "")
    entry <- ifelse(vertices[j] == 1, 'ofs',
		    subst('%vertexm1%*stride + ofs',
			  vertexm1 = vertices[j]-1))
    result <- c(result,
      subst(
'  ofs = %prefix%rgl.getObj(%objid%).vOffsets.%attribofs%;
  if (ofs < 0)
    alert("Attribute %attribute% not found in object %objid%");',
        prefix, objid, attribofs = attribofs[attributes[j]],
        attribute = attributes[j]),

      if (attribofsofs[attributes[j]] > 0)
      	subst(
'  ofs = ofs + %attribofsofs%;', attribofsofs = attribofsofs[attributes[j]]),

      if (interp) subst(
'  v1 = values[%multiplier%(i-1)%offset%];
  v2 = values[%multiplier%i%offset%];
  propvals[%entry%] = p*v1 + (1-p)*v2;',
        entry, multiplier, offset)
      else if (!direct) subst(
'  propvals[%entry%] = values[%multiplier%value%offset%];',
	entry, multiplier, offset)
      else if (ncol == 1) subst(
'  propvals[%entry%] = value;',
      	entry)
      else subst(
'  propvals[%entry%] = value[%jm1%];',
      	entry, jm1 = j - 1))

  }
  result <- c(result,
    if (interp)
'       break;
  }',
    subst(
'  %prefix%rgl.getObj(%objid%).values = propvals;
  if (typeof %prefix%rgl.getObj(%objid%).buf !== "undefined") {
    var gl = %prefix%rgl.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).buf);
    gl.bufferData(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).values, gl.STATIC_DRAW);
  }', prefix, objid))

    result <- c(result, '}')
    structure(paste(result, collapse = "\n"),
      param = param, prefixes = prefix,
      class = c("vertexSetter", "propertySetter"))
}


par3dinterpSetter <- function(fn, from, to, steps, subscene = NULL,
			      omitConstant = TRUE, rename = character(), ...) {
  times <- seq(from, to, length.out = steps+1)
  fvals <- lapply(times, fn)
  f0 <- fvals[[1]]
  entries <- numeric(0)
  properties <- character(0)
  values <- NULL

  props <- c("FOV", "userMatrix", "scale", "zoom")
  for(i in seq_along(props)) {
    prop <- props[i]
    propname <- rename[prop]
    if (is.na(propname))
    	propname <- prop
    if (!is.null(value <- f0[[prop]])) {
      newvals <- sapply(fvals, function(e) as.numeric(e[[prop]]))
      if (is.matrix(newvals)) newvals <- t(newvals)
      rows <- NROW(newvals)
      cols <- NCOL(newvals)
      stopifnot(rows == length(fvals))
      entries <- c(entries, seq_len(cols)-1)
      properties <- c(properties, rep(propname, cols))
      values <- cbind(values, newvals)
    }
  }
  if (omitConstant) keep <- apply(values, 2, var) > 0
  else keep <- TRUE

  if (is.null(subscene)) subscene <- f0$subscene

  propertySetter(values = values[,keep], entries = entries[keep],
		 properties = paste0("par3d.", properties[keep]),
		 objids = subscene, param = times, ...)
}

matrixSetter <- function(fns, from, to, steps, subscene = currentSubscene3d(), matrix = "userMatrix",
			omitConstant = TRUE, prefix = "", ...) {
  n <- length(fns)
  from <- rep(from, length.out = n)
  to <- rep(to, length.out = n)
  steps <- rep(steps, length.out = n)
  settername <- basename(tempfile("fn", ""))
  propname <- paste0("userMatrix", settername) # Needs to match "^userMatrix" regexp
  param <- numeric()
  prefixes <- character()
  result <- subst(
'%prefix%rgl.%settername% = function(value, index){
     var fns = new Array();', prefix, settername)
  product <- ''
  for (i in seq_len(n)) {
    setter <- par3dinterpSetter(fns[[i]], from[i], to[i], steps[i],
    			        omitConstant = TRUE, subscene = i-1, prefixes = prefix,
    			        rename = c(userMatrix = propname), ...)
    result <- c(result, subst(
'     fns[%i%] = ', i=i-1), setter)
    param <- c(param, attr(setter, "param"))
  }
  result <- c(result,
'   fns[index](value);
   var newmatrix = new CanvasMatrix4();',
    paste0(subst(
'   newmatrix.multLeft(%prefix%rgl.%propname%[', prefix, propname), 0:(n-1), ']);'),
    subst(
'   %prefix%rgl.%matrix%[%subscene%].load(newmatrix);
 }
 %prefix%rgl.%propname% = new Array();', prefix, subscene, propname, matrix),
    paste0(subst(
' %prefix%rgl.%propname%[', prefix, propname), 0:(n-1), '] = new CanvasMatrix4();'))
  structure(paste(result, collapse="\n"),
  	    param = sort(unique(param)),
  	    prefixes = prefix,
  	    name = subst('%prefix%rgl.%settername%', prefix, settername),
  	    class = c("matrixSetter", "indexedSetter", "propertySetter"))
}

print.indexedSetter <- function(x, inScript = FALSE, ...) {
  if (!inScript) cat("<script>\n")
  cat(x)
  if (!inScript) cat("\n</script>")
}

ageSetter <- function(births, ages, colors = NULL, alpha = NULL,
		      radii = NULL, vertices = NULL, normals = NULL,
		      origins = NULL, texcoords = NULL, objids, prefixes = "",
		      digits = 7, param = seq(floor(min(births)), ceiling(max(births))))  {
  formatVec <- function(vec) {
    vec <- t(vec)
    result <- formatC(vec, digits = digits, width = 1)
    result[vec == Inf] <- "Infinity"
    result[vec == -Inf] <- "-Infinity"
    paste(result, collapse = ",")
  }
  if (!is.null(colors)) colors <- t(col2rgb(colors))/255
  lengths <- c(colors = NROW(colors), alpha = length(alpha),
  	       radii = length(radii), vertices = NROW(vertices),
  	       normals = NROW(normals), origins = NROW(origins),
  	       texcoords = NROW(texcoords))
  lengths <- lengths[lengths > 0]
  attribs <- names(lengths)
  n <- unique(lengths)
  stopifnot(length(n) == 1, n == length(ages), all(diff(ages) >= 0))
  nobjs <- max(length(objids), length(prefixes))
  prefixes <- rep(prefixes, length.out = nobjs)
  objids <- rep(objids, length.out = nobjs)
  result <- subst(
'  function(time){
    var ages = [-Infinity, %ages%, Infinity],
        births = [%births%],
        j = new Array(births.length),
        p = new Array(births.length),
        i, age, j0, propvals, stride, ofs;',
    ages = formatVec(ages), births = formatVec(births))
  rows <- c(1,1:n, n)
  if ("colors" %in% attribs)
    result <- c(result, subst(
'    var colors = [%values%];', values = formatVec(colors[rows,])))
  if ("alpha" %in% attribs)
    result <- c(result, subst(
'    var alpha = [%values%];', values = formatVec(alpha[rows])))
  if ("radii" %in% attribs)
    result <- c(result, subst(
'    var radii = [%values%];', values = formatVec(radii[rows])))
  if ("vertices" %in% attribs) {
    stopifnot(ncol(vertices) == 3)
    result <- c(result, subst(
'    var vertices = [%values%];', values = formatVec(vertices[rows,])))
  }
  if ("normals" %in% attribs) {
    stopifnot(ncol(normals) == 3)
    result <- c(result, subst(
'    var normals = [%values%];', values = formatVec(normals[rows,])))
  }
  if ("origins" %in% attribs) {
    stopifnot(ncol(origins) == 2)
    result <- c(result, subst(
'    var origins = [%values%];', values = formatVec(origins[rows,])))
  }
  if ("texcoords" %in% attribs) {
    stopifnot(ncol(texcoords) == 2)
    result <- c(result, subst(
'    var texcoords = [%values%];', values = formatVec(texcoords[rows,])))
  }
  result <- c(result,
'    for (i = 0; i < births.length; i++) {
      age = time - births[i];
      for (j0 = 1; age > ages[j0]; j0++);
      if (ages[j0] == Infinity)
        p[i] = 1;
      else if (ages[j0] > ages[j0-1])
        p[i] = (ages[j0] - age)/(ages[j0] - ages[j0-1]);
      else
        p[i] = 0;
      j[i] = j0;
    }')
  for (j in seq_len(nobjs)) {
    prefix <- prefixes[j]
    objid <- objids[j]
    result <- c(result, subst(
'    propvals = %prefix%rgl.getObj(%objid%).values;
    stride = %prefix%rgl.getObj(%objid%).vOffsets.stride;',
      prefix, objid))
    for (a in attribs) {
      ofs <- c(colors = "cofs", alpha = "cofs", radii = "radofs",
      	       vertices = "vofs", normals = "nofs", origins = "oofs",
      	       texcoords = "tofs")[a]
      result <- c(result, subst(
'    ofs = %prefix%rgl.getObj(%objid%).vOffsets.%ofs%;
    if (ofs >= 0) {
      for (i = 0; i < births.length; i++) {',
        prefix, objid, ofs))
      dim <- c(colors = 3, alpha = 1, radii = 1,
      	 vertices = 3, normals = 3, origins = 2,
      	 texcoords = 2)[a]
      if (dim > 1)
        for (d in seq_len(dim) - 1)
      	  result <- c(result, subst(
'        propvals[i*stride + ofs + %d1%] = p[i]*%a%[%dim%*(j[i]-1) + %d2%] + (1-p[i])*%a%[%dim%*j[i] + %d2%];',
          dim, d1 = if (a == "alpha") 3 else d, d2 = d, a))
      else
      	result <- c(result, subst(
'        propvals[i*stride + ofs%alphaofs%] = p[i]*%a%[j[i]-1] + (1-p[i])*%a%[j[i]];',
      		a, alphaofs = if (a == "alpha") " + 3" else ""))
      result <- c(result, subst(
'      }
    } else
        alert("\'%a%\' property not found in object %objid%");', a, objid))
    }
    result <- c(result, subst(
'    %prefix%rgl.getObj(%objid%).values = propvals;
    if (typeof %prefix%rgl.getObj(%objid%).buf !== "undefined") {
      var gl = %prefix%rgl.gl;
      gl.bindBuffer(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).buf);
      gl.bufferData(gl.ARRAY_BUFFER, %prefix%rgl.getObj(%objid%).values, gl.STATIC_DRAW);
    }',
      prefix, objid))
  }
  result <- c(result, '  }')
  structure(paste(result, collapse = "\n"),
            param = param, prefixes = prefixes,
  	    class = c("ageSetter", "propertySetter"))
}
