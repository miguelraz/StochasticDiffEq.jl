@inline function change_t_via_interpolation!{T}(integrator,t,modify_save_endpoint::Type{Val{T}}=Val{false})
  # Can get rid of an allocation here with a function
  # get_tmp_arr(integrator.cache) which gives a pointer to some
  # cache array which can be modified.
  if t < integrator.tprev
    error("Current interpolant only works between tprev and t")
  elseif t != integrator.t
    if typeof(integrator.u) <: AbstractArray
      integrator(integrator.u,t)
    else
      integrator.u = integrator(t)
    end
    integrator.dtnew = integrator.t - t
    reject_step!(integrator.W,integrator.dtnew) #this only changes dt and noise, so no interpolation problems
    integrator.dt = integrator.dtnew
    integrator.sqdt = sqrt(abs(integrator.dt))
    integrator.t = t
    # reeval_internals_due_to_modification!(integrator) # Not necessary for linear interp
    if T
      solution_endpoint_match_cur_integrator!(integrator)
    end
  end
end

function (integrator::SDEIntegrator)(t,deriv::Type=Val{0};idxs=size(integrator.uprev))
  current_interpolant(t,integrator,idxs,deriv)
end

(integrator::SDEIntegrator)(val::AbstractArray,t::Union{Number,AbstractArray},deriv::Type=Val{0};idxs=eachindex(integrator.uprev)) = current_interpolant!(val,t,integrator,idxs,deriv)


user_cache(integrator::SDEIntegrator) = user_cache(integrator.cache)
u_cache(integrator::SDEIntegrator) = u_cache(integrator.cache)
du_cache(integrator::SDEIntegrator)= du_cache(integrator.cache)
user_cache(c::StochasticDiffEqCache) = (c.u,c.uprev,c.tmp)
full_cache(integrator::SDEIntegrator) = chain(user_cache(integrator),u_cache(integrator),du_cache(integrator.cache))
default_non_user_cache(integrator::SDEIntegrator) = chain(u_cache(integrator),du_cache(integrator.cache))
@inline add_tstop!(integrator::SDEIntegrator,t) = push!(integrator.opts.tstops,t)

resize_non_user_cache!(integrator::SDEIntegrator,i::Int) = resize_non_user_cache!(integrator,integrator.cache,i)
deleteat_non_user_cache!(integrator::SDEIntegrator,i) = deleteat_non_user_cache!(integrator,integrator.cache,i)
addat_non_user_cache!(integrator::SDEIntegrator,i) = addat_non_user_cache!(integrator,integrator.cache,i)
resize!(integrator::SDEIntegrator,i::Int) = resize!(integrator,integrator.cache,i)

function resize!(integrator::SDEIntegrator,cache,i)
  resize_non_user_cache!(integrator,cache,i)
  for c in user_cache(integrator)
    resize!(c,i)
  end
end

function resize_noise!(integrator,cache,bot_idx,i)
  for c in integrator.W.S₁
    resize!(c[2],i)
    if alg_needs_extra_process(integrator.alg)
      resize!(c[3],i)
    end
    if i > bot_idx # fill in rands
      fill_new_noise_caches!(integrator,c,c[1],bot_idx:i)
    end
  end
  for c in integrator.W.S₂
    resize!(c[2],i)
    if alg_needs_extra_process(integrator.alg)
      resize!(c[3],i)
    end
    if i > bot_idx # fill in rands
      fill_new_noise_caches!(integrator,c,c[1],bot_idx:i)
    end
  end
  resize!(integrator.W.dW,i)
  resize!(integrator.W.dWtilde,i)
  resize!(integrator.W.dWtmp,i)
  resize!(integrator.W.curW,i)

  if alg_needs_extra_process(integrator.alg)
    resize!(integrator.W.dZ,i)
    resize!(integrator.W.dZtilde,i)
    resize!(integrator.W.dZtmp,i)
    resize!(integrator.W.curZ,i)
  end
  if i > bot_idx # fill in rands
    fill!(@view(integrator.W.curW[bot_idx:i]),zero(eltype(integrator.u)))
    if alg_needs_extra_process(integrator.alg)
      fill!(@view(integrator.W.curZ[bot_idx:i]),zero(eltype(integrator.u)))
    end
  end
end

@inline function fill_new_noise_caches!(integrator,c,scaling_factor,idxs)
  if isinplace(integrator.W)
    integrator.W.dist(@view(c[2][idxs]),integrator.W,scaling_factor)
    if alg_needs_extra_process(integrator.alg)
      integrator.W.dist(@view(c[3][idxs]),integrator.W,scaling_factor)
    end
  else
    c[2][idxs] .= integrator.noise(length(idxs),integrator,scaling_factor)
    if alg_needs_extra_process(integrator.alg)
      c[3][idxs] .= integrator.noise(length(idxs),integrator,scaling_factor)
    end
  end
end

function resize_non_user_cache!(integrator::SDEIntegrator,cache,i)
  bot_idx = length(integrator.u)
  resize_noise!(integrator,cache,bot_idx,i)
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
end

function deleteat!(integrator::SDEIntegrator,idxs)
  deleteat_non_user_cache!(integrator,cache,idxs)
  for c in user_cache(integrator)
    deleteat!(c,idxs)
  end
end

function addat!(integrator::SDEIntegrator,idxs)
  addat_non_user_cache!(integrator,cache,idxs)
  for c in user_cache(integrator)
    addat!(c,idxs)
  end
end

function deleteat_non_user_cache!(integrator::SDEIntegrator,cache,idxs)
  deleteat_noise!(integrator,cache,idxs)
  i = length(integrator.u)
  # Ordering doesn't matter in these caches
  # So just resize
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
end

function addat_non_user_cache!(integrator::SDEIntegrator,cache,idxs)
  addat_noise!(integrator,cache,idxs)
  i = length(integrator.u)
  # Ordering doesn't matter in these caches
  # So just resize
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
end

function deleteat_noise!(integrator,cache,idxs)
  for c in integrator.W.S₁
    deleteat!(c[2],idxs)
    if alg_needs_extra_process(integrator.alg)
      deleteat!(c[3],idxs)
    end
  end
  for c in integrator.W.S₂
    deleteat!(c[2],idxs)
    if alg_needs_extra_process(integrator.alg)
      deleteat!(c[3],idxs)
    end
  end
  deleteat!(integrator.W.dW,idxs)
  deleteat!(integrator.W.dWtilde,idxs)
  deleteat!(integrator.W.dWtmp,idxs)
  deleteat!(integrator.W.curW,idxs)

  if alg_needs_extra_process(integrator.alg)
    deleteat!(integrator.W.curZ,idxs)
    deleteat!(integrator.W.dZtmp,idxs)
    deleteat!(integrator.W.dZtilde,idxs)
    deleteat!(integrator.W.dZ,idxs)
  end
end

function addat_noise!(integrator,cache,idxs)
  for c in integrator.W.S₁
    addat!(c[2],idxs)
    if alg_needs_extra_process(integrator.alg)
      addat!(c[3],idxs)
    end
    fill_new_noise_caches!(integrator,c,c[1],idxs)
  end
  for c in integrator.W.S₂
    addat!(c[2],idxs)
    if alg_needs_extra_process(integrator.alg)
      addat!(c[3],idxs)
    end
    fill_new_noise_caches!(integrator,c,c[1],idxs)
  end

  addat!(integrator.W.dW,idxs)
  addat!(integrator.W.curW,idxs)
  if alg_needs_extra_process(integrator.alg)
    addat!(integrator.W.dZ,idxs)
    addat!(integrator.W.curZ,idxs)
  end

  i = length(integrator.u)
  resize!(integrator.W.dWtilde,i)
  resize!(integrator.W.dWtmp,i)
  if alg_needs_extra_process(integrator.alg)
    resize!(integrator.W.dZtmp,i)
    resize!(integrator.W.dZtilde,i)
  end

  # fill in rands
  fill!(@view(integrator.W.curW[idxs]),zero(eltype(integrator.u)))
  if alg_needs_extra_process(integrator.alg)
    fill!(@view(integrator.W.curZ[idxs]),zero(eltype(integrator.u)))
  end
end


function terminate!(integrator::SDEIntegrator)
  integrator.opts.tstops.valtree = typeof(integrator.opts.tstops.valtree)()
end
