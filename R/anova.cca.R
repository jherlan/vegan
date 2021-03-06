`anova.cca` <-
    function(object, ..., permutations = how(nperm=999), by = NULL,
             model = c("reduced", "direct", "full"),
             parallel = getOption("mc.cores"), strata = NULL,
             cutoff = 1, scope = NULL) 
{
    model <- match.arg(model)
    ## permutations is either a single number, a how() structure or a
    ## permutation matrix
    if (length(permutations) == 1) {
        nperm <- permutations
        permutations <- how(nperm = nperm)
    }
    if (!is.null(strata)) {
        if (!inherits(permutations, "how"))
            stop("'strata' can be used only with simple permutation or with 'how()'")
        if (!is.null(permutations$block))
            stop("'strata' cannot be applied when 'blocks' are defined in 'how()'")
        setBlocks(permutations) <- strata
    }
    ## now permutations is either a how() structure or a permutation
    ## matrix. Make it to a matrix if it is "how"
    if (inherits(permutations, "how")) {
        permutations <- shuffleSet(nrow(object$CA$u),
                                   control = permutations)
        seed <- attr(permutations, "seed")
        control <- attr(permutations, "control")
    }
    else # we got a permutation matrix and seed & control are unknown
        seed <- control <- NULL
    nperm <- nrow(permutations)
    ## stop permutations block
    ## see if this was a list of ordination objects
    dotargs <- list(...)
    ## we do not want to give dotargs to anova.ccalist, but we
    ## evaluate 'parallel' and 'model' here
    if (length(dotargs)) {
        isCCA <- sapply(dotargs, function(z) inherits(z, "cca"))
        if (any(isCCA)) {
            dotargs <- dotargs[isCCA]
            object <- c(list(object), dotargs)
            sol <-
                anova.ccalist(object, 
                              permutations = permutations,
                              model = model,
                              parallel = parallel)
            attr(sol, "Random.seed") <- seed
            attr(sol, "control") <- control
            return(sol)
        }
    }
    ## We only have a single model: check if it is empty
    if (is.null(object$CA) || is.null(object$CCA) ||
        object$CCA$rank == 0 || object$CA$rank == 0)
        return(anova.ccanull(object))
    ## by cases
    if (!is.null(by)) {
        by <- match.arg(by, c("terms", "margin", "axis"))
        sol <- switch(by,
                      "terms" = anova.ccabyterm(object,
                      permutations = permutations,
                      model = model, parallel = parallel),
                      "margin" = anova.ccabymargin(object,
                      permutations = permutations,
                      model = model, parallel = parallel,
                      scope = scope),
                      "axis" = anova.ccabyaxis(object,
                      permutations = permutations,
                      model = model, parallel = parallel,
                      cutoff = cutoff))
        attr(sol, "Random.seed") <- seed
        attr(sol, "control") <- control
        return(sol)
    }
    ## basic overall test
    tst <- permutest.cca(object, permutations = permutations, ...)
    Fval <- c(tst$F.0, NA)
    Pval <- (sum(tst$F.perm >= tst$F.0) + 1)/(tst$nperm + 1)
    Pval <- c(Pval, NA)
    table <- data.frame(tst$df, tst$chi, Fval, Pval)
    is.rda <- inherits(object, "rda")
    colnames(table) <- c("Df", ifelse(is.rda, "Variance", "ChiSquare"), 
                         "F", "Pr(>F)")
    head <- paste0("Permutation test for ", tst$method, " under ", 
                  tst$model, " model\n", howHead(control))
    mod <- paste("Model:", c(object$call))
    structure(table, heading = c(head, mod), Random.seed = seed,
              control = control,
              class = c("anova.cca", "anova", "data.frame"))
}
