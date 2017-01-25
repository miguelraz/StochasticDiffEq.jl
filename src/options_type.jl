type SDEOptions{uEltype,uEltypeNoUnits,tTypeNoUnits,tType,F2,F3,F4,F5,F6,tstopsType,ECType}
  maxiters::Int
  timeseries_steps::Int
  save_timeseries::Bool
  adaptive::Bool
  abstol::uEltype
  reltol::uEltypeNoUnits
  gamma::tTypeNoUnits
  qmax::tTypeNoUnits
  qmin::tTypeNoUnits
  dtmax::tType
  dtmin::tType
  internalnorm::F2
  tstops::tstopsType
  saveat::tstopsType
  d_discontinuities::tstopsType
  userdata::ECType
  progress::Bool
  progress_steps::Int
  progress_name::String
  progress_message::F5
  timeseries_errors::Bool
  dense_errors::Bool
  beta1::tTypeNoUnits
  beta2::tTypeNoUnits
  delta::uEltypeNoUnits
  qoldinit::tTypeNoUnits
  dense::Bool
  save_noise::Bool
  callback::F3
  isoutofdomain::F4
  unstable_check::F6
  calck::Bool
  advance_to_tstop::Bool
  stop_at_next_tstop::Bool
end
