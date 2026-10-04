class_name Draws
extends RefCounted
## Where a server's numbers come from (SH12): its room codes' letters and its matches'
## seeds, each from Draws of their own. Every player is shown the seeds, so what draws
## the codes must give nothing of itself away through them: SeededDraws repeats for the
## tests and a --seed run, SecureDraws (scenes/online) draws codes on every server.


## A number in [0, [param count]), each as likely as the others.
func below(_count: int) -> int:
	return 0


## A number in [0, 2^32).
func u32() -> int:
	return 0
